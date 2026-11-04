import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/up_stat_filter.dart';
import 'package:PiliPlus/utils/zone_filter.dart';

/// 单条正则单独兜底：坏一条不影响其它条，避免"规则半新半旧"
RegExp _buildRegExp(String pattern, RegExp fallback) {
  if (pattern.isEmpty) return RegExp('');
  try {
    return RegExp(pattern, caseSensitive: false);
  } catch (_) {
    return fallback;
  }
}

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
  DynamicsDataModel.antiGoodsDyn = Pref.antiGoodsDyn;
  UpStatFilter.reload();

  RecommendFilter.rcmdRegExp = _buildRegExp(
    Pref.banWordForRecommend,
    RecommendFilter.rcmdRegExp,
  );
  RecommendFilter.enableFilter = RecommendFilter.rcmdRegExp.pattern.isNotEmpty;
  RecommendFilter.upNameRegExp = _buildRegExp(
    Pref.banUpNames,
    RecommendFilter.upNameRegExp,
  );
  RecommendFilter.enableUpName =
      RecommendFilter.upNameRegExp.pattern.isNotEmpty;
  ReplyGrpc.replyRegExp = _buildRegExp(
    Pref.banWordForReply,
    ReplyGrpc.replyRegExp,
  );
  ReplyGrpc.enableFilter = ReplyGrpc.replyRegExp.pattern.isNotEmpty;
  VideoHttp.zoneRegExp = _buildRegExp(
    Pref.banWordForZone,
    VideoHttp.zoneRegExp,
  );
  VideoHttp.enableFilter = VideoHttp.zoneRegExp.pattern.isNotEmpty;
  DynamicsDataModel.banWordForDyn = _buildRegExp(
    Pref.banWordForDyn,
    DynamicsDataModel.banWordForDyn,
  );
  DynamicsDataModel.enableFilter =
      DynamicsDataModel.banWordForDyn.pattern.isNotEmpty;

  ZoneFilter.reload();
}
