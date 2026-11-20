import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_insets_safe_area.dart';
import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

class WebDavSettingPage extends StatefulWidget {
  const WebDavSettingPage({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  State<WebDavSettingPage> createState() => _WebDavSettingPageState();
}

class _WebDavSettingPageState extends State<WebDavSettingPage> {
  final _uriCtr = TextEditingController(text: Pref.webdavUri);
  final _usernameCtr = TextEditingController(text: Pref.webdavUsername);
  final _passwordCtr = TextEditingController(text: Pref.webdavPassword);
  final _directoryCtr = TextEditingController(text: Pref.webdavDirectory);
  bool _obscureText = true;

  @override
  void dispose() {
    _uriCtr.dispose();
    _usernameCtr.dispose();
    _passwordCtr.dispose();
    _directoryCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final padding = MediaQuery.viewPaddingOf(context);
    return SimpleScaffold(
      appBar: showAppBar ? AppBar(title: const Text('WebDAV 设置')) : null,
      body: ViewInsetsSafeArea(
        child: ListView(
          padding: padding.copyWith(
            top: 20,
            left: 20 + (showAppBar ? padding.left : 0),
            right: 20 + (showAppBar ? padding.right : 0),
            bottom: padding.bottom + 100,
          ),
          children: [
            TextField(
              controller: _uriCtr,
              decoration: const InputDecoration(
                labelText: '地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameCtr,
              decoration: const InputDecoration(
                labelText: '用户',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordCtr,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: '密码',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                  icon: _obscureText
                      ? const Icon(Icons.visibility)
                      : const Icon(Icons.visibility_off),
                ),
              ),
              obscureText: _obscureText,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _directoryCtr,
              decoration: const InputDecoration(
                labelText: '路径',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: Style.mdRadius,
                      ),
                    ),
                    onPressed: WebDav().backup,
                    child: const Text('备份设置'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: Style.mdRadius,
                      ),
                    ),
                    onPressed: WebDav().restore,
                    child: const Text('恢复设置'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: Style.mdRadius,
                      ),
                    ),
                    onPressed: WebDav().backupBlacklist,
                    child: const Text('备份黑名单'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: Style.mdRadius,
                      ),
                    ),
                    onPressed: WebDav().restoreBlacklist,
                    child: const Text('恢复黑名单'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: Style.mdRadius,
                      ),
                    ),
                    onPressed: WebDav().backupBlockTags,
                    child: const Text('备份标签'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: Style.mdRadius,
                      ),
                    ),
                    onPressed: WebDav().restoreBlockTags,
                    child: const Text('恢复标签'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: Style.mdRadius,
                      ),
                    ),
                    onPressed: WebDav().backupFilterRules,
                    child: const Text('备份过滤规则'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: Style.mdRadius,
                      ),
                    ),
                    onPressed: WebDav().restoreFilterRules,
                    child: const Text('恢复过滤规则'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '过滤规则含：评论/标题/分区/动态关键词、直播弹幕词、视频弹幕词、SC 金额、标签名单，'
              '以及屏蔽开关与阈值（UID 位数、投稿数、带货、只@、已关注豁免、时长/播放/点赞率）。\n'
              '关键词与名单按并集合并；开关和阈值按备份覆盖，保证各设备一致。\n'
              '含括号分组或内容无效的正则不做并集，改为按备份覆盖，恢复时会提示哪几条需要核对。\n'
              '注：「备份标签 / 恢复标签」等同于过滤规则里的标签部分，单独留着方便只同步标签。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      fab: Padding(
        padding: .only(
          right: kFloatingActionButtonMargin + (showAppBar ? padding.right : 0),
          bottom: kFloatingActionButtonMargin + padding.bottom,
        ),
        child: ViewInsetsSafeArea(
          child: FloatingActionButton(
            child: const Icon(Icons.save),
            onPressed: () async {
              await GStorage.setting.putAll({
                SettingBoxKey.webdavUri: _uriCtr.text,
                SettingBoxKey.webdavUsername: _usernameCtr.text,
                SettingBoxKey.webdavPassword: _passwordCtr.text,
                SettingBoxKey.webdavDirectory: _directoryCtr.text,
              });
              if (_uriCtr.text.isEmpty) {
                return;
              }
              try {
                final res = await WebDav().init();
                if (res.first) {
                  SmartDialog.showToast('配置成功');
                } else {
                  SmartDialog.showToast('配置失败: ${res.second}');
                }
              } catch (e) {
                SmartDialog.showToast('配置失败: ${e.toString()}');
                return;
              }
            },
          ),
        ),
      ),
    );
  }
}
