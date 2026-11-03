import 'package:PiliPlus/utils/storage_pref.dart';

/// 分区白名单：只保留勾选的分区，其余全部不显示。
/// 没勾任何一个 = 不启用。
///
/// 选项不是硬编码分区表，而是"推荐里真实出现过的 tname"，
/// 所以设置页可以直接列出可点项。
abstract final class ZoneFilter {
  static const int _maxSeen = 200;

  static Set<String>? _cache;
  static Set<String>? _allowedCache;
  static DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  /// 白名单解析结果缓存：每张卡片都会查一次，不能每次都去 split 字符串
  static Set<String> get _allowed => _allowedCache ??= Pref.allowZones;

  /// 白名单被改过（设置页保存 / WebDAV 恢复）后必须调一次
  static void reload() => _allowedCache = null;

  static bool get enabled => _allowed.isNotEmpty;

  /// 已收集到的分区名（按首次出现顺序）
  static Set<String> get seen => _cache ??= Pref.seenZones;

  /// true = 保留；false = 过滤掉
  ///
  /// 精确匹配（忽略大小写）：选项本身就是真实分区名，
  /// 用包含匹配会出现"勾了短名字连带放行一堆"的问题。
  /// 接口没给分区名时按放行处理——宁可漏进来，也不要把界面清空。
  static bool allow(String? tname) {
    final allowed = _allowed;
    if (allowed.isEmpty) return true;
    final name = tname?.trim().toLowerCase();
    if (name == null || name.isEmpty) return true;
    return allowed.contains(name);
  }

  /// 记录一条分区名，供设置页显示成可点的选项
  static void note(String? tname) {
    final name = tname?.trim();
    if (name == null || name.isEmpty) return;
    final cache = seen;
    if (!cache.add(name)) return;
    if (cache.length > _maxSeen) cache.remove(cache.first);
    // 别每条都写 Hive，30 秒最多落盘一次
    if (DateTime.now().difference(_lastFlush).inSeconds >= 30) {
      flush();
    }
  }

  /// 打开设置页时调用，确保最近的收集结果已落盘
  static void flush() {
    _lastFlush = DateTime.now();
    Pref.seenZones = seen;
  }
}
