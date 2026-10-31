import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveDmBlockController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final TabController tabController;

  /// 本地关键词（不依赖账号，换行或逗号分隔存储）
  final RxList<String> keywordList = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);
    keywordList.addAll(Pref.liveBlockKeywords);
  }

  /// 直播弹幕同时按本地黑名单过滤，这里只用于展示数量
  int get blacklistCount => GlobalData().blackMids.length;

  void addKeyword(String value) {
    final word = value.trim();
    if (word.isEmpty) return;
    final words = Pref.liveBlockKeywords..add(word);
    Pref.liveBlockKeywords = words;
    if (!keywordList.contains(word)) {
      keywordList.insert(0, word);
    }
  }

  void removeKeyword(int index) {
    final word = keywordList[index];
    final words = Pref.liveBlockKeywords..remove(word);
    Pref.liveBlockKeywords = words;
    keywordList.removeAt(index);
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }
}
