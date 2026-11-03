import 'dart:convert';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

typedef _WebDavConfig = ({
  String uri,
  String username,
  String password,
  String directory,
});

class WebDav {
  _WebDavConfig? _clientConfig;
  webdav.Client? _client;

  WebDav._internal();
  static final WebDav _instance = WebDav._internal();
  factory WebDav() => _instance;

  _WebDavConfig _getConfig() {
    String directory = Pref.webdavDirectory;
    if (!directory.endsWith('/')) {
      directory += '/';
    }
    return (
      uri: Pref.webdavUri,
      username: Pref.webdavUsername,
      password: Pref.webdavPassword,
      directory: '$directory${Constants.appName}',
    );
  }

  Future<webdav.Client> _connect(
    _WebDavConfig config, {
    bool force = false,
  }) async {
    final cachedClient = _client;
    if (!force && cachedClient != null && _clientConfig == config) {
      return cachedClient;
    }

    final client =
        webdav.newClient(
            config.uri,
            user: config.username,
            password: config.password,
          )
          ..setHeaders({'accept-charset': 'utf-8'})
          ..setConnectTimeout(12000)
          ..setReceiveTimeout(12000)
          ..setSendTimeout(12000);

    await client.mkdirAll(config.directory);
    _clientConfig = config;
    _client = client;
    return client;
  }

  Future<Pair<bool, String?>> init() async {
    try {
      await _connect(_getConfig(), force: true);

      return Pair(first: true, second: null);
    } catch (e) {
      return Pair(first: false, second: e.toString());
    }
  }

  String _getFileName() {
    return 'piliplus_settings_${DeviceUtils.platformName}.json';
  }

  Future<void> backup() async {
    // Keep the payload bound to the same settings snapshot as the connection.
    final config = _getConfig();
    final data = GStorage.exportAllSettings();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('备份失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/${_getFileName()}';
      try {
        await client.remove(path);
      } catch (_) {}
      await client.write(path, utf8.encode(data));
      SmartDialog.showToast('备份成功');
    } catch (e) {
      SmartDialog.showToast('备份失败: $e');
    }
  }

  Future<void> restore() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('恢复失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/${_getFileName()}';
      final data = await client.read(path);
      await GStorage.importAllSettings(utf8.decode(data));
      SmartDialog.showToast('恢复成功');
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    }
  }

  /// 黑名单单独同步：固定文件名，三平台通用
  static const String _blacklistFileName = 'piliplus_blacklist.json';

  Future<void> backupBlacklist() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('备份失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/$_blacklistFileName';
      try {
        await client.remove(path);
      } catch (_) {}
      await client.write(path, utf8.encode(GStorage.exportBlacklist()));
      SmartDialog.showToast('已备份黑名单 ${Pref.blackMids.length} 人');
    } catch (e) {
      SmartDialog.showToast('备份失败: $e');
    }
  }

  Future<void> restoreBlacklist() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('恢复失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/$_blacklistFileName';
      final data = await client.read(path);
      final ids = GStorage.parseBlacklist(utf8.decode(data));
      if (ids.isEmpty) {
        SmartDialog.showToast('备份里没有黑名单');
        return;
      }
      final before = Pref.blackMids.length;
      final total = GStorage.mergeBlacklist(ids);
      SmartDialog.showToast(
        '已合并：备份 ${ids.length} 人 / 新增 ${total - before} 人 / 共 $total 人',
      );
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    }
  }

  /// 搜索标签黑名单单独同步：固定文件名，三平台通用
  static const String _blockTagsFileName = 'piliplus_block_tags.json';

  Future<void> backupBlockTags() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('备份失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/$_blockTagsFileName';
      try {
        await client.remove(path);
      } catch (_) {}
      await client.write(path, utf8.encode(GStorage.exportBlockTags()));
      SmartDialog.showToast('已备份标签黑名单');
    } catch (e) {
      SmartDialog.showToast('备份失败: $e');
    }
  }

  Future<void> restoreBlockTags() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('恢复失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/$_blockTagsFileName';
      final data = await client.read(path);
      final raw = GStorage.parseBlockTags(utf8.decode(data));
      if (raw.trim().isEmpty) {
        SmartDialog.showToast('备份里没有标签黑名单');
        return;
      }
      final total = GStorage.mergeBlockTags(raw);
      SmartDialog.showToast('已合并标签，共 $total 个');
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    }
  }

  /// 分区白名单单独同步：固定文件名，三平台通用
  /// 恢复是整份覆盖（白名单做并集只会越并越宽松）
  static const String _allowZonesFileName = 'piliplus_allow_zones.json';

  Future<void> backupAllowZones() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('备份失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/$_allowZonesFileName';
      try {
        await client.remove(path);
      } catch (_) {}
      await client.write(path, utf8.encode(GStorage.exportAllowZones()));
      SmartDialog.showToast('已备份分区白名单 ${Pref.allowZones.length} 个');
    } catch (e) {
      SmartDialog.showToast('备份失败: $e');
    }
  }

  Future<void> restoreAllowZones() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('恢复失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/$_allowZonesFileName';
      final data = await client.read(path);
      final raw = GStorage.parseAllowZones(utf8.decode(data));
      if (raw.trim().isEmpty) {
        SmartDialog.showToast('备份里没有分区白名单');
        return;
      }
      final total = GStorage.applyAllowZones(raw);
      SmartDialog.showToast('已恢复分区白名单，共 $total 个（覆盖本地）');
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    }
  }

  /// 过滤规则单独同步：评论/标题/分区/动态关键词、直播弹幕词、SC 阈值、标签黑名单
  /// 只做并集合并，完全不碰播放设置与界面设置
  static const String _filterRulesFileName = 'piliplus_filter_rules.json';

  Future<void> backupFilterRules() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('备份失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/$_filterRulesFileName';
      try {
        await client.remove(path);
      } catch (_) {}
      await client.write(path, utf8.encode(GStorage.exportFilterRules()));
      SmartDialog.showToast('已备份过滤规则');
    } catch (e) {
      SmartDialog.showToast('备份失败: $e');
    }
  }

  Future<void> restoreFilterRules() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('恢复失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/$_filterRulesFileName';
      final data = await client.read(path);
      final rules = GStorage.parseFilterRules(utf8.decode(data));
      if (rules.isEmpty) {
        SmartDialog.showToast('备份里没有过滤规则');
        return;
      }
      final res = GStorage.mergeFilterRules(rules);
      // 关键词是启动时读进静态字段的，这里就地刷新，省一次重启
      try {
        ReplyGrpc.replyRegExp = RegExp(
          Pref.banWordForReply,
          caseSensitive: false,
        );
        ReplyGrpc.enableFilter = ReplyGrpc.replyRegExp.pattern.isNotEmpty;
        RecommendFilter.rcmdRegExp = RegExp(
          Pref.banWordForRecommend,
          caseSensitive: false,
        );
        RecommendFilter.enableFilter =
            RecommendFilter.rcmdRegExp.pattern.isNotEmpty;
        VideoHttp.zoneRegExp = RegExp(Pref.banWordForZone, caseSensitive: false);
        VideoHttp.enableFilter = VideoHttp.zoneRegExp.pattern.isNotEmpty;
        DynamicsDataModel.banWordForDyn = RegExp(
          Pref.banWordForDyn,
          caseSensitive: false,
        );
        DynamicsDataModel.enableFilter =
            DynamicsDataModel.banWordForDyn.pattern.isNotEmpty;
      } catch (_) {}
      SmartDialog.showToast(
        '已合并过滤规则：关键词更新 ${res.patterns} 组 / '
        '直播词 ${res.liveWords} 个 / 弹幕词 ${res.danmakuWords} 个 / '
        '标签 ${res.tags} 个 / SC 阈值 ${res.scPrice} 元',
      );
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    }
  }
}
