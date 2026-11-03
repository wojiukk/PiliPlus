import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/zone_filter.dart';

/// 整包恢复设置后，把内存里的静态过滤状态重新读一遍。
/// 这些字段都是启动时从 Hive 读进 static 的，不刷新的话要重启才生效。
void refreshFilterState() {
  final gd = GlobalData();
  gd.blockSnowflakeUid = Pref.blockSnowflakeUid;
  // 黑名单可能被整包覆盖，CRC 哈希之类的缓存要失效
  gd.blacklistVersion++;

  RecommendFilter.minDurationForRcmd = Pref.minDurationForRcmd;
  RecommendFilter.minPlayForRcmd = Pref.minPlayForRcmd;
  RecommendFilter.minLikeRatioForRecommend = Pref.minLikeRatioForRecommend;
  RecommendFilter.exemptFilterForFollowed = Pref.exemptFilterForFollowed;
  RecommendFilter.applyFilterToRelatedVideos = Pref.applyFilterToRelatedVideos;

  ReplyGrpc.antiGoodsReply = Pref.antiGoodsReply;
  ReplyGrpc.blockAtOnlyReply = Pref.blockAtOnlyReply;
  ReplyGrpc.blockReplyAtCount = Pref.blockReplyAtCount;
  ReplyGrpc.blockReplyLevel = Pref.blockReplyLevel;
  ReplyGrpc.blockFansMedals = Pref.blockFansMedals;

  try {
    RecommendFilter.rcmdRegExp = RegExp(
      Pref.banWordForRecommend,
      caseSensitive: false,
    );
    RecommendFilter.enableFilter =
        RecommendFilter.rcmdRegExp.pattern.isNotEmpty;
    RecommendFilter.upNameRegExp = RegExp(Pref.banUpNames, caseSensitive: false);
    RecommendFilter.enableUpName =
        RecommendFilter.upNameRegExp.pattern.isNotEmpty;
    ReplyGrpc.replyRegExp = RegExp(Pref.banWordForReply, caseSensitive: false);
    ReplyGrpc.enableFilter = ReplyGrpc.replyRegExp.pattern.isNotEmpty;
    VideoHttp.zoneRegExp = RegExp(Pref.banWordForZone, caseSensitive: false);
    VideoHttp.enableFilter = VideoHttp.zoneRegExp.pattern.isNotEmpty;
    DynamicsDataModel.banWordForDyn = RegExp(
      Pref.banWordForDyn,
      caseSensitive: false,
    );
    DynamicsDataModel.enableFilter =
        DynamicsDataModel.banWordForDyn.pattern.isNotEmpty;
  } catch (_) {}

  ZoneFilter.reload();
}
