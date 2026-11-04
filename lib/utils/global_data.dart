import 'package:PiliPlus/utils/storage_pref.dart';

class GlobalData {
  int imgQuality = Pref.picQuality;

  num? coins;

  void afterCoin(num coin) {
    if (coins != null) {
      coins = coins! - coin;
    }
  }

  Set<int> blackMids = Pref.blackMids;

  /// 黑名单版本号：任何增删都会 +1，供 CRC 哈希这类缓存失效用
  int blacklistVersion = 0;

  bool dynamicsWaterfallFlow = Pref.dynamicsWaterfallFlow;

  bool showMedal = Pref.showMedal;

  /// 按 UID 位数屏蔽（16 位及以上；这类号多为 2023 年后注册的雪花 ID）
  bool blockSnowflakeUid = Pref.blockSnowflakeUid;

  /// 16 位及以上即视为"长 UID"账号
  static const int snowflakeUidMinLength = 16;

  /// 把 int / String / Int64 / num 统一成 int，解析失败返回 null
  static int? uidOf(Object? mid) {
    if (mid == null) return null;
    if (mid is int) return mid;
    if (mid is num) return mid.toInt();
    return int.tryParse(mid.toString().trim());
  }

  static bool isSnowflakeUid(Object? mid) {
    final uid = uidOf(mid);
    if (uid == null || uid <= 0) return false;
    return uid.toString().length >= snowflakeUidMinLength;
  }

  /// 只查本地黑名单，不参与「按 UID 位数屏蔽」
  bool isBlacklisted(Object? mid) {
    final uid = uidOf(mid);
    return uid != null && blackMids.contains(uid);
  }

  /// 本地黑名单命中，或（开关打开时）是长 UID 账号
  /// 先把 UID 规范成 int 再查黑名单，避免接口给字符串时漏判
  ///
  /// [exemptFollowed] = 已关注的 UP：黑名单仍然生效（那是你亲手加的），
  /// 但不套用「按位数屏蔽」——关注了就不该因为注册晚被整片挡掉
  bool shouldBlockUid(Object? mid, {bool exemptFollowed = false}) {
    final uid = uidOf(mid);
    if (uid == null) return false;
    if (blackMids.contains(uid)) return true;
    if (exemptFollowed) return false;
    return blockSnowflakeUid && isSnowflakeUid(uid);
  }

  // 私有构造函数
  GlobalData._();

  // 单例实例
  static final GlobalData _instance = GlobalData._();

  // 获取全局实例
  factory GlobalData() => _instance;
}

extension IterableExt<E> on Iterable<E> {
  Iterable<E> whereNotBlocked(Object? /* mid */ Function(E element) test) =>
      where((e) => !GlobalData().shouldBlockUid(test(e)));
}
