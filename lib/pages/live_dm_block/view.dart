import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/pages/live_dm_block/controller.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveDmBlockPage extends StatefulWidget {
  const LiveDmBlockPage({super.key});

  @override
  State<LiveDmBlockPage> createState() => _LiveDmBlockPageState();
}

class _LiveDmBlockPageState extends State<LiveDmBlockPage> {
  final _controller = Get.put(
    LiveDmBlockController(),
    tag: Utils.generateRandomString(8),
  );
  late EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    padding = MediaQuery.viewPaddingOf(context);
    Widget tabBar = TabBar(
      controller: _controller.tabController,
      tabs: const [
        Tab(text: '关键词'),
        Tab(text: '用户'),
      ],
    );

    Widget view = tabBarView(
      hitTestBehavior: .translucent,
      controller: _controller.tabController,
      children: [
        KeepAliveWrapper(child: Obx(_buildKeyword)),
        KeepAliveWrapper(child: _buildUser()),
      ],
    );

    return SimpleScaffold(
      appBar: AppBar(title: const Text('弹幕屏蔽')),
      body: Padding(
        padding: .only(left: padding.left, right: padding.right),
        child: Column(
          children: [
            tabBar,
            Expanded(child: view),
          ],
        ),
      ),
      fab: Padding(
        padding: .only(
          right: kFloatingActionButtonMargin + padding.right,
          bottom: kFloatingActionButtonMargin + padding.bottom,
        ),
        child: FloatingActionButton(
          tooltip: '添加关键词',
          onPressed: _addKeyword,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildKeyword() {
    final list = _controller.keywordList;
    if (list.isEmpty) {
      return scrollableError;
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 12,
        left: 12,
        right: 12,
        bottom: padding.bottom + 100,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: list.mapIndexed(
          (i, e) {
            return SearchText(
              text: e,
              onTap: (value) => showConfirmDialog(
                context: context,
                title: const Text('确定删除该关键词？'),
                onConfirm: () => _controller.removeKeyword(i),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _buildUser() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: padding.bottom + 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '直播弹幕按本地黑名单过滤',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            '当前本地黑名单：${_controller.blacklistCount} 人',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '名单在「设置 → 黑名单」里管理；黑名单支持 WebDAV 同步，多个账号、多台设备共用同一份。',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _addKeyword() {
    String value = '';
    showConfirmDialog(
      context: context,
      title: const Text('添加屏蔽关键词'),
      content: TextFormField(
        autofocus: true,
        onChanged: (val) => value = val,
      ),
      onConfirm: () {
        if (value.isNotEmpty) {
          _controller.addKeyword(value);
        }
      },
    );
  }
}
