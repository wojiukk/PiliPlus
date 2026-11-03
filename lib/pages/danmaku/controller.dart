import 'dart:collection';
import 'dart:convert' show ascii;
import 'dart:io' show File;

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/grpc/dm.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:archive/archive.dart' show getCrc32;
import 'package:path/path.dart' as path;

class PlDanmakuController {
  PlDanmakuController(
    this._cid,
    this._plPlayerController,
    this._isFileSource,
  ) : _mergeDanmaku = _plPlayerController.mergeDanmaku;

  final int _cid;
  final PlPlayerController _plPlayerController;
  final bool _mergeDanmaku;
  final bool _isFileSource;

  late final _isLogin = Accounts.main.isLogin;

  final Map<int, List<DanmakuElem>> _dmSegMap = HashMap();
  // 已请求的段落标记
  late final Set<int> _requestedSeg = HashSet();

  void dispose() {
    _dmSegMap.clear();
    _requestedSeg.clear();
  }

  Future<void> queryDanmaku(int segmentIndex) async {
    if (_isFileSource) {
      return;
    }
    if (_requestedSeg.contains(segmentIndex)) {
      return;
    }
    _requestedSeg.add(segmentIndex);
    final res = await DmGrpc.dmSegMobile(
      cid: _cid,
      segmentIndex: segmentIndex + 1,
    );

    if (res case Success(:final response)) {
      if (response.state == 1) {
        _plPlayerController.dmState.add(_cid);
      }
      handleDanmaku(response.elems);
    } else {
      _requestedSeg.remove(segmentIndex);
    }
  }

  /// 把本地黑名单的 mid 换算成弹幕用的 midHash（crc32 十六进制），
  /// 和「弹幕屏蔽 - 用户」用的是同一套算法。
  /// 名单大时每段弹幕都重算很浪费：按 GlobalData 的黑名单版本号缓存，
  /// 版本号只增不减，增删都会失效（不能只比长度，换人时长度可能不变）。
  static Set<String>? _hashCache;
  static int _hashCacheVersion = -1;

  Set<String> _buildBlacklistHashes() {
    final gd = GlobalData();
    final mids = gd.blackMids;
    if (mids.isEmpty) return const <String>{};
    if (_hashCache != null && _hashCacheVersion == gd.blacklistVersion) {
      return _hashCache!;
    }
    final hashes = mids
        .map((mid) => getCrc32(ascii.encode('$mid'), 0).toRadixString(16))
        .toSet();
    _hashCache = hashes;
    _hashCacheVersion = gd.blacklistVersion;
    return hashes;
  }

  void handleDanmaku(List<DanmakuElem> elems) {
    if (elems.isEmpty) return;
    final uniques = HashMap<String, DanmakuElem>();

    final filters = _plPlayerController.filters;
    final shouldFilter = filters.count != 0;
    final blockHashes = _buildBlacklistHashes();
    // 本地关键词：纯文本匹配（自动转义），不依赖登录
    final blockWords = Pref.danmakuBlockWords;
    final localWordExp = blockWords.isEmpty
        ? null
        : RegExp(blockWords.map(RegExp.escape).join('|'), caseSensitive: false);
    for (final element in elems) {
      if (_isLogin) {
        element.isSelf = element.midHash == _plPlayerController.midHash;
      }

      if (!element.isSelf) {
        // 本地黑名单用户的弹幕直接丢弃
        if (blockHashes.contains(element.midHash)) {
          continue;
        }

        // 本地关键词
        if (localWordExp != null && localWordExp.hasMatch(element.content)) {
          continue;
        }

        if (_mergeDanmaku) {
          final elem = uniques[element.content];
          if (elem == null) {
            uniques[element.content] = element..count = 1;
          } else {
            elem.count++;
            continue;
          }
        }

        if (shouldFilter && filters.remove(element)) {
          continue;
        }
      }

      final int pos = element.progress ~/ 100; //每0.1秒存储一次
      (_dmSegMap[pos] ??= []).add(element);
    }
  }

  List<DanmakuElem>? getCurrentDanmaku(int progress) {
    if (_isFileSource) {
      initFileDmIfNeeded();
    } else {
      final int segmentIndex = DmUtils.calcSegment(progress);
      if (!_requestedSeg.contains(segmentIndex)) {
        queryDanmaku(segmentIndex);
        return null;
      }
    }
    return _dmSegMap[progress ~/ 100];
  }

  bool _fileDmLoaded = false;

  void initFileDmIfNeeded() {
    if (_fileDmLoaded) return;
    _fileDmLoaded = true;
    _initFileDm();
  }

  @pragma('vm:notify-debugger-on-exception')
  Future<void> _initFileDm() async {
    try {
      final file = File(
        path.join(
          (_plPlayerController.dataSource as FileSource).dir,
          PathUtils.danmakuName,
        ),
      );
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final elem = DmSegMobileReply.fromBuffer(bytes).elems;
      handleDanmaku(elem);
    } catch (e, s) {
      Utils.reportError(e, s);
    }
  }
}
