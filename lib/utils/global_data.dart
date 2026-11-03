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

  bool dynamicsWaterfallFlow = Pref.dynamicsWaterfallFlow;

  bool showMedal = Pref.showMedal;

  /// 屏蔽 16 位及以上 UID（2023 年后注册的雪花 ID 账号）
  bool blockSnowflakeUid = Pref.blockSnowflakeUid;

  /// 16 位及以上即视为雪花 ID 账号（2023 年后注册）
  static const int snowflakeUidMinLength = 16;

  static bool isSnowflakeUid(Object? mid) {
    if (mid == null) return false;
    final uid = mid is num ? mid.toInt() : int.tryParse('$mid'.trim());
    if (uid == null || uid <= 0) return false;
    return uid.toString().length >= snowflakeUidMinLength;
  }

  /// 本地黑名单命中，或（开关打开时）是 16 位雪花 ID 账号
  bool shouldBlockUid(Object? mid) =>
      blackMids.contains(mid) || (blockSnowflakeUid && isSnowflakeUid(mid));

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
