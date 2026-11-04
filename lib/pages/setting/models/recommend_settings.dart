import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/up_stat_filter.dart';
import 'package:flutter/foundation.dart';
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
    title: '按 UID 位数屏蔽（16 位及以上）',
    subtitle:
        '作用域: 评论、首页推荐、热门/排行、相关视频、搜索结果、直播弹幕\n'
        '动态流不套用这条规则（那里全是关注的人）\n'
        '16 位及以上属于「长 UID」号，多为 2023 年后注册；只是近似，不等于注册时间\n'
        '纯本地判断，默认关闭',
    leading: const Icon(Icons.block),
    setKey: SettingBoxKey.blockSnowflakeUid,
    defaultVal: false,
    onChanged: (value) => GlobalData().blockSnowflakeUid = value,
  ),
  SwitchModel(
    title: '投稿数屏蔽',
    subtitle: '投稿数低于下限的 UP 不显示（首页推荐已接；热门/相关视频暂未接）',
    leading: const Icon(Icons.video_library_outlined),
    setKey: UpStatFilter.enabledKey,
    defaultVal: false,
    onChanged: (value) => UpStatFilter.apply(enabled: value),
  ),
  NormalModel(
    title: '投稿数下限',
    leading: const Icon(Icons.numbers),
    getSubtitle: () =>
        '当前 ${UpStatFilter.minUploads} 条｜低于它的 UP 会被挡，点这里改',
    onTap: (context, setState) => showUpStatThresholdDialog(context, setState),
  ),
  getBlockTagsModel(
    title: '搜索标签黑名单',
    key: SettingBoxKey.blockSearchTags,
    scope: '搜索结果（综合/视频）',
  ),
];

/// 投稿数下限：数字自己填，0 = 不屏蔽
void showUpStatThresholdDialog(BuildContext context, VoidCallback setState) {
  var text = '${UpStatFilter.minUploads}';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('投稿数下限'),
      content: TextFormField(
        initialValue: text,
        autofocus: true,
        decoration: const InputDecoration(
          helperText: '低于这个投稿数的 UP 不显示；0 = 不屏蔽',
          isDense: true,
        ),
        onChanged: (v) => text = v,
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        TextButton(
          onPressed: () {
            final v = int.tryParse(text.trim());
            UpStatFilter.apply(minUploads: v ?? UpStatFilter.minUploads);
            Get.back();
            setState();
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
