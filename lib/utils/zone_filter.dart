import 'package:PiliPlus/utils/storage_pref.dart';

/// 分区白名单：只保留勾选的分区，其余全部不显示。
/// 没勾任何一个 = 不启用。
///
/// 顺带把推荐里出现过的分区名收集起来，供设置页做"点选"，
/// 这样不用手打分区名。
abstract final class ZoneFilter {
  static const int _maxSeen = 200;

  static Set<String>? _cache;
  static DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  static Set<String> get _allowed => Pref.allowZones;

  static bool get enabled => _allowed.isNotEmpty;

  /// 已收集到的分区名（按首次出现顺序）
  static Set<String> get seen => _cache ??= Pref.seenZones;

  /// true = 保留；false = 过滤掉
  static bool allow(String? tname) {
    final allowed = _allowed;
    if (allowed.isEmpty) return true;
    // 接口没给分区名时不误杀
    if (tname == null || tname.isEmpty) return true;
    final name = tname.toLowerCase();
    for (final word in allowed) {
      if (name.contains(word)) return true;
    }
    return false;
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
