import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  /// 一屏能放几条差别很大：桌面 7 列 × 4 行 ≈ 28，笔记本/小窗 ≈ 24，手机 ≈ 6。
  /// 目标取「大约 1.5~3 屏」：桌面 36，手机 18。
  /// 只要超过一屏高度，页面就能滚动，滚到底才会正常触发加载下一页。
  static int get _minCount => PlatformUtils.isMobile ? 18 : 36;

  /// 最多补几页，防止过滤太狠时无限请求
  static const int _maxExtra = 3;

  /// 本次请求是从哪一页开始的（补页会改动 page，用它判断"是不是刷新第一页"）
  int _basePage = 0;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  /// 网页推荐接口的 ps 只认 20，要更大只能多拉一页（下面的补水）。
  Future<LoadingState> _fetch(int idx) => appRcmd
      ? VideoHttp.rcmdVideoListApp(freshIdx: idx)
      : VideoHttp.rcmdVideoList(freshIdx: idx, ps: 20);

  /// 首屏过滤后不够一屏（桌面 36 / 手机 18）就往下补，最多 3 页。
  /// 补页只在刷新时做，加载更多不打这个补丁，避免滚动时二次等待。
  /// 补完把多拉的页数记到 page 上，下一轮不会重复请求同一页。
  @override
  Future<LoadingState> customGetData() async {
    _basePage = page;
    final first = await _fetch(page);
    if (first is! Success<List>) {
      return first;
    }
    final data = first.response;
    // 只在"刷新首屏"时补水；加载更多时一页够用，别再多等
    if (_basePage != 0 || data.length >= _minCount) {
      return first;
    }

    var extra = 0;
    var used = 0;
    while (data.length < _minCount && extra < _maxExtra) {
      extra++;
      final more = await _fetch(page + extra);
      if (more is! Success<List>) {
        break;
      }
      used = extra;
      if (more.response.isNotEmpty) {
        data.addAll(more.response);
      }
    }
    if (used > 0) {
      page += used;
    }
    return first;
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData;
  }

  @override
  void handleListResponse(List dataList) {
    // 用 _basePage 判断，因为 page 可能已经被补页改动
    if (enableSaveLastData && _basePage == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          // 旧列表是"当时"过滤过的，现在设置可能变了，
          // 复用前必须重跑：账号黑名单 + 分区（黑名单/白名单）+ 推荐过滤
          final kept = response
              .where((e) {
                if (e is! BaseRcmdVideoItemModel) return false;
                if (GlobalData().shouldBlockUid(e.owner.mid)) return false;
                if (!VideoHttp.allowZone(e.tname)) return false;
                return !RecommendFilter.filterWithExempt(e);
              })
              .toList();
          dataList.addAll(kept.length > 200 ? kept.take(50) : kept);
        }
      }
    }
  }

  /// 拉黑某个 UP 后，立刻把当前列表里他的视频清掉（不用等刷新）
  void removeUpFromList(int? mid) {
    if (mid == null) return;
    if (loadingState.value case Success(:final response?)) {
      final before = response.length;
      response.removeWhere(
        (e) => e is BaseVideoItemModel && e.owner.mid == mid,
      );
      if (response.length != before) {
        loadingState.refresh();
      }
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    return queryData();
  }
}
