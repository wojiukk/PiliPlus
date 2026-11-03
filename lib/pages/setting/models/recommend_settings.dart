import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/zone_filter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide StatefulBuilder;

List<SettingsModel> get recommendSettings => [
  const SwitchModel(
    title: '首页使用app端推荐',
    subtitle: '若web端推荐不太符合预期，可尝试切换至app端推荐',
    leading: Icon(Icons.model_training_outlined),
    setKey: SettingBoxKey.appRcmd,
    defaultVal: true,
    needReboot: true,
  ),
  SwitchModel(
    title: '保留首页推荐刷新',
    subtitle: '下拉刷新时保留上次内容',
    leading: const Icon(Icons.refresh),
    setKey: SettingBoxKey.enableSaveLastData,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..enableSaveLastData = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  SwitchModel(
    title: '显示上次看到位置提示',
    subtitle: '保留上次推荐时，在上次刷新位置显示提示',
    leading: const Icon(Icons.tips_and_updates_outlined),
    setKey: SettingBoxKey.savedRcmdTip,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..savedRcmdTip = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  getVideoFilterSelectModel(
    title: '点赞率',
    suffix: '%',
    key: SettingBoxKey.minLikeRatioForRecommend,
    values: [0, 1, 2, 3, 4],
    onChanged: (value) => RecommendFilter.minLikeRatioForRecommend = value,
    filterScope: 'Web推荐、热门、分区',
  ),
  getBanWordModel(
    title: '标题关键词过滤',
    key: SettingBoxKey.banWordForRecommend,
    onChanged: (value) {
      RecommendFilter.rcmdRegExp = value;
      RecommendFilter.enableFilter = value.pattern.isNotEmpty;
    },
    banScope: '推荐、热门、分区、相关视频',
  ),
  getBanWordModel(
    title: 'UP 名字关键词过滤',
    key: SettingBoxKey.banUpNames,
    onChanged: (value) {
      RecommendFilter.upNameRegExp = value;
      RecommendFilter.enableUpName = value.pattern.isNotEmpty;
    },
    banScope: '推荐、热门/排行、相关视频、直播列表（搜索不受影响）',
  ),
  getBanWordModel(
    title: '分区关键词过滤',
    key: SettingBoxKey.banWordForZone,
    onChanged: (value) {
      VideoHttp.zoneRegExp = value;
      VideoHttp.enableFilter = value.pattern.isNotEmpty;
    },
    banScope: 'App推荐、热门、分区',
  ),
  getVideoFilterSelectModel(
    title: '视频时长',
    suffix: 's',
    key: SettingBoxKey.minDurationForRcmd,
    values: [0, 30, 60, 90, 120],
    onChanged: (value) => RecommendFilter.minDurationForRcmd = value,
    filterScope: '推荐、相关视频',
  ),
  getVideoFilterSelectModel(
    title: '播放量',
    key: SettingBoxKey.minPlayForRcmd,
    values: [0, 50, 100, 500, 1000],
    onChanged: (value) => RecommendFilter.minPlayForRcmd = value,
    filterScope: '推荐、热门、分区、相关视频',
  ),
  SwitchModel(
    title: '已关注UP豁免推荐过滤',
    subtitle: '推荐中已关注用户发布的内容不会被过滤',
    leading: const Icon(Icons.favorite_border_outlined),
    setKey: SettingBoxKey.exemptFilterForFollowed,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.exemptFilterForFollowed = value,
  ),
  SwitchModel(
    title: '过滤器也应用于详情页相关视频',
    subtitle: '其它（如热门视频、搜索等）均不受过滤器影响，无法豁免相关视频中的已关注UP',
    leading: const Icon(Icons.explore_outlined),
    setKey: SettingBoxKey.applyFilterToRelatedVideos,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.applyFilterToRelatedVideos = value,
  ),
  SwitchModel(
    title: '屏蔽16位ID账号（2023年后注册）',
    subtitle:
        '作用域: 评论、首页推荐、热门/排行、相关视频、搜索结果、直播弹幕\n'
        'UID 位数 ≥ 16 即视为新注册账号，纯本地判断、不额外请求\n'
        '注意: 2023 年后注册的真人同样会被隐藏，默认关闭',
    leading: const Icon(Icons.block),
    setKey: SettingBoxKey.blockSnowflakeUid,
    defaultVal: false,
    onChanged: (value) => GlobalData().blockSnowflakeUid = value,
  ),
  NormalModel(
    title: '只看这些分区（点选）',
    leading: const Icon(Icons.playlist_add_check),
    getSubtitle: () {
      final zones = Pref.allowZones;
      if (zones.isEmpty) return '未启用｜点这里勾选想看的分类';
      final shown = zones.take(4).join('、');
      return '已勾选 ${zones.length} 个：$shown${zones.length > 4 ? '…' : ''}';
    },
    onTap: (context, setState) => showZonePicker(context, setState),
  ),
  getBlockTagsModel(
    title: '搜索标签黑名单',
    key: SettingBoxKey.blockSearchTags,
    scope: '搜索结果（综合/视频）',
  ),
];

/// 分区白名单选择框：选项来自 ZoneFilter 收集到的真实分区名
void showZonePicker(BuildContext context, VoidCallback setState) {
  ZoneFilter.flush();
  showDialog(
    context: context,
    builder: (_) => const _ZonePickerDialog(),
  ).then((_) => setState());
}

class _ZonePickerDialog extends StatefulWidget {
  const _ZonePickerDialog();

  @override
  State<_ZonePickerDialog> createState() => _ZonePickerDialogState();
}

class _ZonePickerDialogState extends State<_ZonePickerDialog> {
  late final List<String> _available = ZoneFilter.seen.toList()..sort();
  late final Set<String> _selected = {...Pref.allowZones};
  final _customCtr = TextEditingController();

  @override
  void dispose() {
    _customCtr.dispose();
    super.dispose();
  }

  void _save() {
    final extra = _customCtr.text
        .split(RegExp(r'[,，\s]+'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty);
    _selected.addAll(extra);
    Pref.allowZones = _selected;
    Get.back();
    SmartDialog.showToast(
      _selected.isEmpty ? '已关闭白名单' : '已保存 ${_selected.length} 个分区',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      constraints: Style.dialogFixedConstraints,
      title: const Text('只看这些分区'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '勾选后，推荐里只保留这些分区，其他全部隐藏；一个都不勾 = 不启用。\n'
                '选项来自你最近刷到过的分区，刷得越多越全。',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_available.isEmpty)
                const Text('还没收集到分区，先去首页刷几屏再回来。')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final z in _available)
                      FilterChip(
                        label: Text(z),
                        selected: _selected.contains(z.toLowerCase()),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _selected.add(z.toLowerCase());
                          } else {
                            _selected.remove(z.toLowerCase());
                          }
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customCtr,
                decoration: const InputDecoration(
                  labelText: '手动补充（可选，逗号分隔）',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        TextButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
