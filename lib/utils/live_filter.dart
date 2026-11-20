import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';

/// 直播列表过滤：黑名单 / 16 位ID / 标题关键词 / 主播名 / 分区关键词
/// 只做判断，0 额外请求；首页直播、分区、分区详情共用
abstract final class LiveFilter {
  static bool shouldBlock(CardLiveItem? item) {
    if (item == null) return false;
    if (GlobalData().shouldBlockUid(item.uid)) return true;
    // 主播名字关键词（与视频侧共用一份词表）
    if (RecommendFilter.filterUpName(item.uname)) return true;

    if (RecommendFilter.enableFilter) {
      final exp = RecommendFilter.rcmdRegExp;
      final title = item.title;
      if (title != null && title.isNotEmpty && exp.hasMatch(title)) {
        return true;
      }
    }

    if (VideoHttp.enableFilter) {
      final area = item.areaName;
      if (area != null && area.isNotEmpty && VideoHttp.zoneRegExp.hasMatch(area)) {
        return true;
      }
    }
    return false;
  }
}
