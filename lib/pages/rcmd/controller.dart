import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
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

  Future<LoadingState> _fetch(int idx) => appRcmd
      ? VideoHttp.rcmdVideoListApp(freshIdx: idx)
      : VideoHttp.rcmdVideoList(freshIdx: idx, ps: 20);

  /// 先拉一页，过滤后（过滤在 VideoHttp 里做）不够 20 条就继续往下拉，
  /// 最多补 3 页。补完把多拉的页数记到 page 上，避免下一轮重复请求。
  @override
  Future<LoadingState> customGetData() async {
    _basePage = page;
    final first = await _fetch(page);
    if (first is! Success<List>) {
      return first;
    }
    final data = first.response;
    if (data.length >= _minCount) {
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
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
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
