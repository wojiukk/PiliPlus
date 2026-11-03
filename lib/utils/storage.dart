import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/user/danmaku_rule_adapter.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account_adapter.dart';
import 'package:PiliPlus/utils/accounts/account_type_adapter.dart';
import 'package:PiliPlus/utils/accounts/cookie_jar_adapter.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/set_int_adapter.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

abstract final class GStorage {
  static late final Box<UserInfoData> userInfo;
  static late final Box<dynamic> historyWord;
  static late final Box<dynamic> localCache;
  static late final Box<dynamic> setting;
  static late final Box<dynamic> video;
  static late final Box<int> watchProgress;
  static late final Box<Uint8List>? reply;

  static Future<void> init() async {
    Hive.init(path.join(appSupportDirPath, 'hive'));
    regAdapter();

    await Future.wait([
      // 登录用户信息
      Hive.openBox<UserInfoData>(
        'userInfo',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 2;
        },
      ).then((res) => userInfo = res),
      // 本地缓存
      Hive.openBox(
        'localCache',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => localCache = res),
      // 设置
      Hive.openBox('setting').then((res) => setting = res),
      // 搜索历史
      Hive.openBox(
        'historyWord',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 10;
        },
      ).then((res) => historyWord = res),
      // 视频设置
      Hive.openBox('video').then((res) => video = res),
      Accounts.init(),
      Hive.openBox<int>(
        'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => watchProgress = res),
    ]);

    if (Pref.saveReply) {
      reply = await Hive.openBox<Uint8List>(
        'reply',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 10;
        },
      );
    } else {
      reply = null;
    }
  }

  static String exportAllSettings() {
    return Utils.jsonEncoder.convert({
      setting.name: setting.toMap(),
      video.name: video.toMap(),
      // 黑名单在 localCache box 里，不随 setting 一起导出，这里单独带一份
      LocalCacheKey.blackMids: Pref.blackMids.toList(),
    });
  }

  static Future<void> importAllSettings(String data) =>
      importAllJsonSettings(jsonDecode(data));

  static Future<List<void>> importAllJsonSettings(
    Map<String, dynamic> map,
  ) {
    // 老备份（或别人的备份）里没有该键时保留本地黑名单，不清空
    if (map[LocalCacheKey.blackMids] case final List<dynamic> list) {
      final ids = Set<int>.from(list.whereType<int>());
      // 必须就地修改：GlobalData() 是单例，blackMids 在构造时已绑定这个 Set，
      // whereNotBlocked 全程读该引用；换成新 Set 会导致本次进程仍按旧名单过滤
      final set = GlobalData().blackMids
        ..clear()
        ..addAll(ids);
      Pref.blackMids = set;
    }
    return Future.wait([
      setting.clear().then((_) => setting.putAll(map[setting.name])),
      video.clear().then((_) => video.putAll(map[video.name])),
    ]);
  }

  /// 仅导出黑名单（WebDAV 单独同步用，不含设置）
  static String exportBlacklist() => Utils.jsonEncoder.convert({
    LocalCacheKey.blackMids: Pref.blackMids.toList(),
  });

  /// 解析黑名单备份，返回其中的 mid 集合；格式不对时返回空集合
  static Set<int> parseBlacklist(String data) {
    final map = jsonDecode(data);
    if (map is Map) {
      if (map[LocalCacheKey.blackMids] case final List<dynamic> list) {
        return Set<int>.from(list.whereType<int>());
      }
    }
    return <int>{};
  }

  /// 合并黑名单（本地 ∪ [ids]），返回合并后的总人数
  static int mergeBlacklist(Set<int> ids) {
    final set = GlobalData().blackMids..addAll(ids);
    Pref.blackMids = set;
    return set.length;
  }

  /// 仅导出搜索标签黑名单（WebDAV 单独同步用）
  static String exportBlockTags() => Utils.jsonEncoder.convert({
    SettingBoxKey.blockSearchTags: Pref.blockSearchTagsRaw,
  });

  /// 解析标签黑名单备份，返回原始文本；格式不对时返回空字符串
  static String parseBlockTags(String data) {
    final map = jsonDecode(data);
    if (map is Map) {
      if (map[SettingBoxKey.blockSearchTags] case final String tags) {
        return tags;
      }
      if (map[SettingBoxKey.blockSearchTags] case final List<dynamic> list) {
        return list.whereType<String>().join('\n');
      }
    }
    return '';
  }

  /// 合并标签黑名单（本地 ∪ [raw]），返回合并后的标签总数
  /// 按小写判重，保留用户原本的写法
  static int mergeBlockTags(String raw) {
    Iterable<String> split(String value) => value
        .split(RegExp(r'[,，\n\r|、]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    final seen = <String>{};
    final merged = <String>[];
    for (final tag in [...split(Pref.blockSearchTagsRaw), ...split(raw)]) {
      if (seen.add(tag.toLowerCase())) merged.add(tag);
    }
    Pref.blockSearchTags = merged.toSet();
    return merged.length;
  }

  /// ===== 分区白名单单独同步 =====

  /// 仅导出分区白名单
  static String exportAllowZones() =>
      Utils.jsonEncoder.convert({SettingBoxKey.allowZones: Pref.allowZonesRaw});

  /// 解析分区白名单备份。
  /// - 字段不存在 → null（不是白名单备份，忽略）
  /// - 合法空字符串 / 全字符串的空列表 → ''（表示"清空白名单"）
  /// - 类型不对 → null（拒绝覆盖，别把错误数据当清空）
  static String? parseAllowZones(String data) {
    final map = jsonDecode(data);
    if (map is! Map || !map.containsKey(SettingBoxKey.allowZones)) return null;
    final value = map[SettingBoxKey.allowZones];
    if (value is String) return value;
    if (value is List && value.every((e) => e is String)) {
      return value.join('\n');
    }
    return null;
  }

  /// 应用分区白名单：整份覆盖（白名单做并集只会越并越宽松），返回总数
  static int applyAllowZones(String raw) {
    final zones = raw
        .split(RegExp(r'[,，\n\r|、]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    Pref.allowZones = zones;
    return zones.length;
  }

  /// ===== 过滤规则同步（只含关键词/标签/SC，不含播放与界面设置）=====

  static const String _filterRulesKey = 'filterRules';
  static const String _filterRulesVersionKey = 'version';

  /// 导出过滤规则：七个键，独立于整包设置
  static String exportFilterRules() => Utils.jsonEncoder.convert({
    _filterRulesVersionKey: 1,
    _filterRulesKey: {
      SettingBoxKey.banWordForReply: Pref.banWordForReply,
      SettingBoxKey.banWordForRecommend: Pref.banWordForRecommend,
      SettingBoxKey.banWordForZone: Pref.banWordForZone,
      SettingBoxKey.banUpNames: Pref.banUpNames,
      SettingBoxKey.banWordForDyn: Pref.banWordForDyn,
      SettingBoxKey.liveBlockKeywords: Pref.liveBlockKeywordsRaw,
      SettingBoxKey.danmakuBlockWords: Pref.danmakuBlockWordsRaw,
      SettingBoxKey.allowZones: Pref.allowZonesRaw,
      SettingBoxKey.blockSearchTags: Pref.blockSearchTagsRaw,
      SettingBoxKey.superChatMinPrice: Pref.superChatMinPrice,
    },
  });

  /// 解析过滤规则备份；也兼容直接把键值放在顶层的文件
  static Map<String, dynamic> parseFilterRules(String data) {
    final map = jsonDecode(data);
    if (map is! Map) return const {};
    final rules = map[_filterRulesKey] ?? map;
    if (rules is! Map) return const {};
    return Map<String, dynamic>.from(rules);
  }

  static Iterable<String> _splitWords(String value) => value
      .split(RegExp(r'[,，\n\r|、]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty);

  static bool _isValidPattern(String pattern) {
    if (pattern.isEmpty) return true;
    try {
      RegExp(pattern);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 正则关键词按 | 求并集；合并结果非法时保留本地，避免启动时崩溃
  static String _mergePattern(String local, String remote) {
    final remoteText = remote.trim();
    if (remoteText.isEmpty) return local;
    if (local.trim().isEmpty) {
      return _isValidPattern(remoteText) ? remoteText : local;
    }
    final seen = <String>{};
    final parts = <String>[];
    for (final raw in [...local.split('|'), ...remoteText.split('|')]) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      if (seen.add(part.toLowerCase())) parts.add(part);
    }
    final merged = parts.join('|');
    return _isValidPattern(merged) ? merged : local;
  }

  /// 关键词/标签按小写去重，保留用户原本写法
  static List<String> _mergeWords(String local, String remote) {
    final seen = <String>{};
    final list = <String>[];
    for (final word in [..._splitWords(local), ..._splitWords(remote)]) {
      if (seen.add(word.toLowerCase())) list.add(word);
    }
    return list;
  }

  /// 合并过滤规则（并集），返回合并后的统计供提示用
  static ({
    int patterns,
    int liveWords,
    int danmakuWords,
    int tags,
    int scPrice,
  })
  mergeFilterRules(Map<String, dynamic> remote) {
    String remoteText(String key) {
      final value = remote[key];
      return value is String ? value : '';
    }

    var patterns = 0;
    void mergePatternKey(String key, String local) {
      final merged = _mergePattern(local, remoteText(key));
      if (merged != local) {
        setting.put(key, merged);
        patterns++;
      }
    }

    mergePatternKey(SettingBoxKey.banWordForReply, Pref.banWordForReply);
    mergePatternKey(SettingBoxKey.banWordForRecommend, Pref.banWordForRecommend);
    mergePatternKey(SettingBoxKey.banWordForZone, Pref.banWordForZone);
    mergePatternKey(SettingBoxKey.banUpNames, Pref.banUpNames);
    mergePatternKey(SettingBoxKey.banWordForDyn, Pref.banWordForDyn);

    final liveWords = _mergeWords(
      Pref.liveBlockKeywordsRaw,
      remoteText(SettingBoxKey.liveBlockKeywords),
    );
    Pref.liveBlockKeywords = liveWords.toSet();

    final danmakuWords = _mergeWords(
      Pref.danmakuBlockWordsRaw,
      remoteText(SettingBoxKey.danmakuBlockWords),
    );
    Pref.danmakuBlockWords = danmakuWords.toSet();

    final tags = _mergeWords(
      Pref.blockSearchTagsRaw,
      remoteText(SettingBoxKey.blockSearchTags),
    );
    Pref.blockSearchTags = tags.toSet();

    // 分区白名单是"只保留"，做并集只会越同步越宽松，
    // 所以只在本地为空时导入，否则保留本地那一份
    final remoteZones = _mergeWords(
      '',
      remoteText(SettingBoxKey.allowZones),
    );
    if (Pref.allowZonesRaw.trim().isEmpty && remoteZones.isNotEmpty) {
      setting.put(SettingBoxKey.allowZones, remoteZones.join('\n'));
    }

    // 金额阈值取两者较大值：屏蔽得更彻底（想反向合并可改成 min）
    var scPrice = Pref.superChatMinPrice;
    final remotePrice = remote[SettingBoxKey.superChatMinPrice];
    if (remotePrice is num) {
      final value = remotePrice.toInt();
      if (value > scPrice) {
        scPrice = value;
        setting.put(SettingBoxKey.superChatMinPrice, value);
      }
    }

    return (
      patterns: patterns,
      liveWords: liveWords.length,
      danmakuWords: danmakuWords.length,
      tags: tags.length,
      scPrice: scPrice,
    );
  }

  static void regAdapter() {
    Hive
      ..registerAdapter(OwnerAdapter())
      ..registerAdapter(UserInfoDataAdapter())
      ..registerAdapter(LevelInfoAdapter())
      ..registerAdapter(BiliCookieJarAdapter())
      ..registerAdapter(LoginAccountAdapter())
      ..registerAdapter(AccountTypeAdapter())
      ..registerAdapter(SetIntAdapter())
      ..registerAdapter(RuleFilterAdapter());
  }

  static Future<List<void>> compact() {
    return Future.wait([
      userInfo.compact(),
      historyWord.compact(),
      localCache.compact(),
      setting.compact(),
      video.compact(),
      Accounts.account.compact(),
      watchProgress.compact(),
      ?reply?.compact(),
    ]);
  }

  static Future<List<void>> close() {
    return Future.wait([
      userInfo.close(),
      historyWord.close(),
      localCache.close(),
      setting.close(),
      video.close(),
      Accounts.account.close(),
      watchProgress.close(),
      ?reply?.close(),
    ]);
  }

  static Future<List<void>> clear() {
    return Future.wait([
      userInfo.clear(),
      historyWord.clear(),
      localCache.clear(),
      setting.clear(),
      video.clear(),
      Accounts.clear(),
      watchProgress.clear(),
      ?reply?.clear(),
    ]);
  }

  static int _intStrDescKeyComparator(dynamic k1, dynamic k2) {
    if (k1 is int) {
      if (k2 is int) {
        return k2.compareTo(k1);
      } else {
        return -1;
      }
    } else if (k2 is String) {
      final lenCompare = k2.length.compareTo((k1 as String).length);
      if (lenCompare == 0) {
        return k2.compareTo(k1);
      } else {
        return lenCompare;
      }
    } else {
      return 1;
    }
  }
}
