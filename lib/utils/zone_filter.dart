/// 分区白名单已移除（勾选项收集不到、也不再参与过滤）。
///
/// 保留同名方法只是让旧的调用点（http/video.dart 等）继续可编译：
/// note 不收集，allow 永远放行，reload/flush 空实现。
abstract final class ZoneFilter {
  static void note(String? tname) {}

  static bool allow(String? tname) => true;

  static void reload() {}

  static void flush() {}

  static bool get enabled => false;

  static Set<String> get seen => const {};
}
