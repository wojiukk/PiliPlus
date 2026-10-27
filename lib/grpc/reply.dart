import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/bilibili/pagination.pb.dart';
import 'package:PiliPlus/grpc/grpc_req.dart';
import 'package:PiliPlus/grpc/url.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:fixnum/fixnum.dart';

abstract final class ReplyGrpc {
  static bool antiGoodsReply = Pref.antiGoodsReply;
  static var blockAtOnlyReply = Pref.blockAtOnlyReply;
  static var blockReplyAtCount = Pref.blockReplyAtCount;
  static var blockReplyLevel = Pref.blockReplyLevel;
  static Set<String> blockFansMedals = Pref.blockFansMedals;
  static RegExp replyRegExp = RegExp(
    Pref.banWordForReply,
    caseSensitive: false,
  );
  static bool enableFilter = replyRegExp.pattern.isNotEmpty;

  // static Future replyInfo({required int rpid}) {
  //   return _request(
  //     GrpcUrl.replyInfo,
  //     ReplyInfoReq(rpid: Int64(rpid)),
  //     ReplyInfoReply.fromBuffer,
  //     onSuccess: (response) => response.reply,
  //   );
  // }

  static bool _hasGoods(Url url) =>
      url.hasExtra() &&
      (url.extra.goodsCmControl == Int64.ONE ||
          url.extra.hasGoodsItemId() ||
          url.extra.hasGoodsPrefetchedCache());

  // ref BiliRoamingX
  @pragma('vm:prefer-inline')
  static bool _needRemoveGoodGrpc(ReplyInfo reply) {
    return (reply.content.urls.isNotEmpty &&
            reply.content.urls.values.any(_hasGoods)) ||
        reply.content.message.contains(Constants.goodsUrlPrefix);
  }

  static bool _blockAtOnlyReply(ReplyInfo reply) {
    if (!blockAtOnlyReply) return false;

    final content = reply.content;
    final atNameToMid = content.atNameToMid;
    if (atNameToMid.isEmpty) return false;
    if (content.emotes.isNotEmpty || content.pictures.isNotEmpty) return false;

    final message = content.message;
    final length = message.length;

    int i = 0;

    if (reply.root != reply.parent) {
      i = message.indexOf(':') + 1;
      if (i <= 0) return false;
    }

    var hasAt = false;
    while (i < length) {
      var c = message.codeUnitAt(i);

      if (c case 0x20 /* ` ` */ || 0x0A /* `\n` */ ) {
        i++;
        continue;
      }

      if (c != 0x40 /* `@` */ ) return false;

      i++;
      final nameStart = i;

      while (i < length) {
        c = message.codeUnitAt(i);
        if (c case 0x20 || 0x40 || 0x0A) {
          break;
        }
        i++;
      }

      if (i == nameStart) return false;
      final name = message.substring(nameStart, i);
      if (!atNameToMid.containsKey(name)) return false;

      hasAt = true;
    }

    return hasAt;
  }

  static bool _blockReplyAtCount(ReplyInfo reply) {
    return blockReplyAtCount != null &&
        reply.content.atNameToMid.length >= blockReplyAtCount!;
  }

  /// 屏蔽低等级评论；[upMid] 用于豁免 UP 本人
  static bool _blockReplyLevel(ReplyInfo reply, Int64? upMid) {
    final maxLevel = blockReplyLevel;
    if (maxLevel <= 0) return false;
    // 豁免 UP 本人和自己
    if (reply.mid == upMid) return false;
    if (reply.mid.toInt() == Accounts.main.mid) return false;
    final member = reply.member;
    // 等级数据缺失（已注销/接口未返回）时不处理，避免误删
    if (!member.hasLevel()) return false;
    return member.level.toInt() <= maxLevel;
  }

  /// 按粉丝牌名字屏蔽（牌子属于观众，只有评论能用到）
  /// 支持模糊匹配：输入的片段包含在牌子名里就算命中，方便只记得个大概
  static bool _blockFansMedal(ReplyInfo reply) {
    if (blockFansMedals.isEmpty) return false;
    final member = reply.member;
    if (!member.hasFansMedalLevel()) return false;
    final name = member.fansMedalName;
    if (name.isEmpty) return false;
    for (final keyword in blockFansMedals) {
      if (name.contains(keyword)) return true;
    }
    return false;
  }

  static bool needRemoveGrpc(ReplyInfo reply, {Int64? upMid}) {
    return GlobalData().blackMids.contains(reply.mid.toInt()) ||
        _blockReplyLevel(reply, upMid) ||
        _blockFansMedal(reply) ||
        _blockReplyAtCount(reply) ||
        _blockAtOnlyReply(reply) ||
        (antiGoodsReply && _needRemoveGoodGrpc(reply)) ||
        (enableFilter && replyRegExp.hasMatch(reply.content.message));
  }

  static Future<LoadingState<MainListReply>> mainList({
    int type = 1,
    required int oid,
    Int64? rpid,
    required Mode mode,
    required String? offset,
    required Int64? cursorNext,
  }) async {
    final res = await GrpcReq.request(
      GrpcUrl.mainList,
      MainListReq(
        oid: Int64(oid),
        type: Int64(type),
        rpid: rpid,
        cursor: CursorReq(
          mode: mode,
          next: cursorNext,
        ),
        // mode: mode,
        // pagination: offset == null ? null : FeedPagination(offset: offset),
      ),
      MainListReply.fromBuffer,
    );
    if (res case Success(:final response)) {
      // keyword filter
      final upMid = response.subjectControl.upMid;
      if (response.hasUpTop() && needRemoveGrpc(response.upTop, upMid: upMid)) {
        response.clearUpTop();
      }

      if (response.replies.isNotEmpty) {
        response.replies.removeWhere((item) {
          final hasMatch = needRemoveGrpc(item, upMid: upMid);
          if (!hasMatch && item.replies.isNotEmpty) {
            item.replies.removeWhere((e) => needRemoveGrpc(e, upMid: upMid));
          }
          return hasMatch;
        });
      }
    }
    return res;
  }

  static Future<LoadingState<DetailListReply>> detailList({
    int type = 1,
    required int oid,
    required int root,
    required int rpid,
    required Mode mode,
    required String? offset,
  }) async {
    final res = await GrpcReq.request(
      GrpcUrl.detailList,
      DetailListReq(
        oid: Int64(oid),
        type: Int64(type),
        root: Int64(root),
        rpid: Int64(rpid),
        scene: DetailListScene.REPLY,
        mode: mode,
        pagination: offset == null ? null : FeedPagination(offset: offset),
      ),
      DetailListReply.fromBuffer,
    );
    return res..dataOrNull?.root.replies.removeWhere(needRemoveGrpc);
  }

  static Future<LoadingState<DialogListReply>> dialogList({
    int type = 1,
    required int oid,
    required int root,
    required int dialog,
    required String? offset,
  }) async {
    final res = await GrpcReq.request(
      GrpcUrl.dialogList,
      DialogListReq(
        oid: Int64(oid),
        type: Int64(type),
        root: Int64(root),
        dialog: Int64(dialog),
        pagination: offset == null ? null : FeedPagination(offset: offset),
      ),
      DialogListReply.fromBuffer,
    );
    return res..dataOrNull?.replies.removeWhere(needRemoveGrpc);
  }

  static Future<LoadingState<SearchItemReply>> searchItem({
    required int page,
    required SearchItemType itemType,
    required int oid,
    int type = 1,
    String? keyword,
  }) {
    return GrpcReq.request(
      GrpcUrl.searchItem,
      SearchItemReq(
        cursor: SearchItemCursorReq(
          next: Int64(page),
          itemType: itemType,
        ),
        oid: Int64(oid),
        type: Int64(type),
        keyword: keyword,
      ),
      SearchItemReply.fromBuffer,
    );
  }

  static Future<LoadingState<TranslateReplyResp>> translateReply({
    required Int64 type,
    required Int64 oid,
    required Int64 rpid,
  }) {
    return GrpcReq.request(
      GrpcUrl.translateReply,
      TranslateReplyReq(
        type: type,
        oid: oid,
        rpids: [rpid],
      ),
      TranslateReplyResp.fromBuffer,
    );
  }
}
