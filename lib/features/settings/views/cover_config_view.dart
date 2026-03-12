import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/settings_service.dart';

/// 封面设置（对齐 legado `pref_config_cover.xml` 的基础可操作项）。
class CoverConfigView extends StatefulWidget {
  const CoverConfigView({super.key});

  @override
  State<CoverConfigView> createState() => _CoverConfigViewState();
}

class _CoverConfigViewState extends State<CoverConfigView> {
  final SettingsService _settingsService = SettingsService();

  bool _loadCoverOnlyWifi = false;
  bool _useDefaultCover = false;
  String _coverRule = '';
  String _defaultCoverPath = '';
  String _defaultCoverDarkPath = '';
  bool _coverShowName = true;
  bool _coverShowAuthor = true;
  bool _coverShowNameNight = true;
  bool _coverShowAuthorNight = true;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
  }

  void _loadFromSettings() {
    setState(() {
      _loadCoverOnlyWifi = _settingsService.coverLoadOnlyWifi;
      _useDefaultCover = _settingsService.useDefaultCover;
      _coverRule = _settingsService.coverRule;
      _defaultCoverPath = _settingsService.defaultCoverPath;
      _defaultCoverDarkPath = _settingsService.defaultCoverDarkPath;
      _coverShowName = _settingsService.coverShowName;
      _coverShowAuthor = _settingsService.coverShowAuthor;
      _coverShowNameNight = _settingsService.coverShowNameNight;
      _coverShowAuthorNight = _settingsService.coverShowAuthorNight;
    });
  }

  Future<void> _editCoverRule() async {
    final initial = _parseCoverRule(_coverRule);
    var enabled = initial.enabled;
    final searchUrlController = TextEditingController(text: initial.searchUrl);
    final coverRuleController = TextEditingController(text: initial.coverRule);

    final action = await showCupertinoBottomDialog<_CoverRuleDialogAction>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => CupertinoAlertDialog(
          title: const Text('封面规则'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('启用')),
                    CupertinoSwitch(
                      value: enabled,
                      onChanged: (value) =>
                          setDialogState(() => enabled = value),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: searchUrlController,
                  placeholder: '搜索url',
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: coverRuleController,
                  placeholder: 'cover规则',
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_CoverRuleDialogAction.delete),
              child: const Text('删除'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                final searchUrl = searchUrlController.text.trim();
                final coverRule = coverRuleController.text.trim();
                if (searchUrl.isEmpty || coverRule.isEmpty) {
                  _showMessage('搜索url和cover规则不能为空');
                  return;
                }
                Navigator.of(dialogContext).pop(_CoverRuleDialogAction.save);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    final normalizedSearchUrl = searchUrlController.text.trim();
    final normalizedCoverRule = coverRuleController.text.trim();
    searchUrlController.dispose();
    coverRuleController.dispose();

    if (action == _CoverRuleDialogAction.delete) {
      await _settingsService.saveCoverRule('');
      if (!mounted) return;
      setState(() => _coverRule = '');
      return;
    }
    if (action != _CoverRuleDialogAction.save) {
      return;
    }

    final encoded = json.encode(<String, dynamic>{
      'enable': enabled,
      'searchUrl': normalizedSearchUrl,
      'coverRule': normalizedCoverRule,
    });
    await _settingsService.saveCoverRule(encoded);
    if (!mounted) return;
    setState(() {
      _coverRule = encoded;
    });
  }

  Future<void> _editDefaultCover({required bool night}) async {
    final currentPath = night ? _defaultCoverDarkPath : _defaultCoverPath;
    if (currentPath.isEmpty) {
      await _pickAndSaveDefaultCover(night: night);
      return;
    }

    final selected = await showAppActionListSheet<_CoverImageAction>(
      context: context,
      title: night ? '夜间默认封面' : '白天默认封面',
      showCancel: true,
      items: const [
        AppActionListItem<_CoverImageAction>(
          value: _CoverImageAction.delete,
          icon: CupertinoIcons.delete,
          label: '删除',
          isDestructiveAction: true,
        ),
        AppActionListItem<_CoverImageAction>(
          value: _CoverImageAction.select,
          icon: CupertinoIcons.photo,
          label: '选择图片',
        ),
      ],
    );

    if (selected == _CoverImageAction.delete) {
      await _saveDefaultCoverPath(night: night, path: null);
      return;
    }
    if (selected == _CoverImageAction.select) {
      await _pickAndSaveDefaultCover(night: night);
    }
  }

  Future<void> _pickAndSaveDefaultCover({required bool night}) async {
    final pickedPath = await _pickAndCopyImage(
      filePrefix: night ? 'default_cover_dark' : 'default_cover_day',
    );
    if (pickedPath == null) return;
    await _saveDefaultCoverPath(night: night, path: pickedPath);
  }

  Future<void> _saveDefaultCoverPath({
    required bool night,
    required String? path,
  }) async {
    if (night) {
      await _settingsService.saveDefaultCoverDarkPath(path);
    } else {
      await _settingsService.saveDefaultCoverPath(path);
    }
    if (!mounted) return;
    setState(() {
      if (night) {
        _defaultCoverDarkPath = (path ?? '').trim();
      } else {
        _defaultCoverPath = (path ?? '').trim();
      }
    });
  }

  Future<String?> _pickAndCopyImage({required String filePrefix}) async {
    if (kIsWeb) {
      _showMessage('当前平台暂不支持选择本地图片');
      return null;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final selected = result.files.first;
      final sourcePath = selected.path?.trim();
      if (sourcePath == null || sourcePath.isEmpty) {
        _showMessage('无法读取图片路径');
        return null;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        _showMessage('图片文件不存在');
        return null;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(docsDir.path, 'settings', 'covers'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final originalName =
          selected.name.trim().isNotEmpty ? selected.name.trim() : 'cover.jpg';
      final sanitizedName =
          originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final extension = p.extension(sanitizedName).toLowerCase();
      final safeExtension = extension.isEmpty ? '.jpg' : extension;
      final targetName =
          '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}$safeExtension';
      final targetPath = p.join(targetDir.path, targetName);
      final savedFile = await sourceFile.copy(targetPath);
      return savedFile.path;
    } catch (error) {
      _showMessage('选择图片失败：$error');
      return null;
    }
  }

  String _pathSummary(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '选择图片';
    if (normalized.length <= 26) return normalized;
    return '${normalized.substring(0, 26)}…';
  }

  _CoverRuleConfig _parseCoverRule(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return const _CoverRuleConfig();
    }
    try {
      final decoded = json.decode(normalized);
      if (decoded is Map) {
        final enableRaw = decoded['enable'];
        final searchUrlRaw = decoded['searchUrl'];
        final coverRuleRaw = decoded['coverRule'];
        final enable = enableRaw is bool
            ? enableRaw
            : enableRaw is num
                ? enableRaw != 0
                : false;
        return _CoverRuleConfig(
          enabled: enable,
          searchUrl: (searchUrlRaw ?? '').toString().trim(),
          coverRule: (coverRuleRaw ?? '').toString().trim(),
        );
      }
    } catch (_) {
      // 兼容历史：旧实现可能只保存了纯文本规则。
    }
    return _CoverRuleConfig(enabled: true, coverRule: normalized);
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '封面设置',
      child: AppListView(
        children: [
          AppListSection(
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('仅 WiFi'),                trailing: CupertinoSwitch(
                  value: _loadCoverOnlyWifi,
                  onChanged: (value) async {
                    await _settingsService.saveCoverLoadOnlyWifi(value);
                    if (!mounted) return;
                    setState(() => _loadCoverOnlyWifi = value);
                  },
                ),
              ),
              AppListTile(
                title: const Text('封面规则'),                onTap: _editCoverRule,
              ),
              AppListTile(
                title: const Text('总是使用默认封面'),                trailing: CupertinoSwitch(
                  value: _useDefaultCover,
                  onChanged: (value) async {
                    await _settingsService.saveUseDefaultCover(value);
                    if (!mounted) return;
                    setState(() => _useDefaultCover = value);
                  },
                ),
              ),
            ],
          ),
          AppListSection(
            header: const Text('白天'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('默认封面'),
                additionalInfo: Text(_pathSummary(_defaultCoverPath)),
                onTap: () => _editDefaultCover(night: false),
              ),
              AppListTile(
                title: const Text('显示书名'),                trailing: CupertinoSwitch(
                  value: _coverShowName,
                  onChanged: (value) async {
                    await _settingsService.saveCoverShowName(value);
                    if (!mounted) return;
                    setState(() => _coverShowName = value);
                  },
                ),
              ),
              AppListTile(
                title: const Text('显示作者'),                trailing: CupertinoSwitch(
                  value: _coverShowAuthor,
                  onChanged: _coverShowName
                      ? (value) async {
                          await _settingsService.saveCoverShowAuthor(value);
                          if (!mounted) return;
                          setState(() => _coverShowAuthor = value);
                        }
                      : null,
                ),
              ),
            ],
          ),
          AppListSection(
            header: const Text('夜间'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('默认封面'),
                additionalInfo: Text(_pathSummary(_defaultCoverDarkPath)),
                onTap: () => _editDefaultCover(night: true),
              ),
              AppListTile(
                title: const Text('显示书名'),                trailing: CupertinoSwitch(
                  value: _coverShowNameNight,
                  onChanged: (value) async {
                    await _settingsService.saveCoverShowNameNight(value);
                    if (!mounted) return;
                    setState(() => _coverShowNameNight = value);
                  },
                ),
              ),
              AppListTile(
                title: const Text('显示作者'),                trailing: CupertinoSwitch(
                  value: _coverShowAuthorNight,
                  onChanged: _coverShowNameNight
                      ? (value) async {
                          await _settingsService
                              .saveCoverShowAuthorNight(value);
                          if (!mounted) return;
                          setState(() => _coverShowAuthorNight = value);
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _CoverImageAction {
  delete,
  select,
}

enum _CoverRuleDialogAction {
  delete,
  save,
}

class _CoverRuleConfig {
  final bool enabled;
  final String searchUrl;
  final String coverRule;

  const _CoverRuleConfig({
    this.enabled = false,
    this.searchUrl = '',
    this.coverRule = '',
  });
}
