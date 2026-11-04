import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage.dart';

/// 按「投稿数」屏蔽：投稿数低于阈值的 UP，其视频不进列表。
///
/// 投稿数不在推荐接口的返回里，只能按 UP 逐个补查
/// （`/x/web-interface/card` 的 `data.archive_count`）。所以策略是：
/// - 每页只查这一页出现过的 UP，同一 UP 一次会话只查一次；
/// - 查询失败 / 超时 / 风控 → 当"未知"处理并**放行**，
///   宁可漏进来，也不要把整页清空；
/// - 缓存只在内存里，重启后第一屏重新补齐，之后零延迟。
abstract final class UpStatFilter {
  /// 开关（设置页「投稿数屏蔽」）
  static const String enabledKey = 'blockLowUploads';

  /// 阈值（设置页「投稿数下限」）
  static const String minKey = 'minUpUploads';

  static bool enabled =
      GStorage.setting.get(enabledKey, defaultValue: false) == true;

  static int minUploads = _readMin();

  static int _readMin() {
    final v = GStorage.setting.get(minKey, defaultValue: 10);
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 10;
  }

  /// mid → 投稿数；-1 = 查过但失败，本次会话不再重试
  static final Map<int, int> _cache = {};

  static bool get active => enabled && minUploads > 0;

  /// 从设置重新读取（WebDAV 恢复 / 整包导入后调用）
  static void reload() {
    enabled = GStorage.setting.get(enabledKey, defaultValue: false) == true;
    minUploads = _readMin();
  }

  /// 没查过的先放行；查过且低于阈值才拦
  static bool shouldBlock(Object? mid) {
    if (!active) return false;
    final uid = GlobalData.uidOf(mid);
    if (uid == null) return false;
    final count = _cache[uid];
    if (count == null || count < 0) return false;
    return count < minUploads;
  }

  /// 给这一页出现的 UP 补查投稿数；任何异常都吞掉，不影响列表
  static Future<void> prefetch(Iterable<Object?> mids) async {
    if (!active) return;
    final todo = <int>[];
    for (final m in mids) {
      final uid = GlobalData.uidOf(m);
      if (uid == null || _cache.containsKey(uid) || todo.contains(uid)) {
        continue;
      }
      todo.add(uid);
    }
    if (todo.isEmpty) return;
    // 并发 4：一页 20 条通常 12~15 个 UP，一次会话第一屏多几百毫秒
    for (var i = 0; i < todo.length; i += 4) {
      await Future.wait(todo.skip(i).take(4).map(_fetch));
    }
  }

  static Future<void> _fetch(int mid) async {
    _cache[mid] = -1; // 占位，避免并发时重复请求同一个 UP
    try {
      final res = await Request()
          .get(
            Api.memberCardInfo,
            queryParameters: {'mid': mid, 'photo': false},
          )
          .timeout(const Duration(milliseconds: 1200));
      if (res.data['code'] == 0) {
        final count = res.data['data']?['archive_count'];
        final n = count is num ? count.toInt() : int.tryParse('$count');
        if (n != null && n >= 0) {
          _cache[mid] = n;
          return;
        }
      }
    } catch (_) {
      // 风控 / 超时 / 断网：保持 -1（放行），不重试
    }
  }

  /// 设置页改动后调用（写盘 + 更新内存）
  static void apply({bool? enabled, int? minUploads}) {
    if (enabled != null) {
      UpStatFilter.enabled = enabled;
      GStorage.setting.put(enabledKey, enabled);
    }
    if (minUploads != null) {
      UpStatFilter.minUploads = minUploads < 0 ? 0 : minUploads;
      GStorage.setting.put(minKey, UpStatFilter.minUploads);
    }
  }
}
