import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../../settings/views/app_help_dialog.dart';
import '../models/dict_rule.dart';
import '../services/dict_rule_store.dart';
import 'dict_rule_edit_view.dart';

class DictRuleManageView extends StatefulWidget {
  const DictRuleManageView({super.key});

  @override
  State<DictRuleManageView> createState() => _DictRuleManageViewState();
}

class _DictRuleManageViewState extends State<DictRuleManageView> {
  static const String _onlineImportHistoryKey = 'dictRuleUrls';

  final DictRuleStore _ruleStore = DictRuleStore();
  final GlobalKey _moreMenuKey = GlobalKey();

  bool _loading = true;
  bool _importingDefault = false;
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _importingQr = false;
  bool _exportingSelection = false;
  bool _enablingSelection = false;
  bool _disablingSelection = false;
  bool _deletingSelection = false;
  bool _selectionMode = false;
  List<DictRule> _rules = const <DictRule>[];
  final Set<String> _selectedRuleNames = <String>{};

  @override
  void initState() {
    super.initState();
    _reloadRules();
  }

  bool get _selectionUpdating => _enablingSelection || _disablingSelection;

  bool get _selectionActionBusy =>
      _selectionUpdating || _exportingSelection || _deletingSelection;

  bool get _menuBusy =>
      _importingDefault ||
      _importingLocal ||
      _importingOnline ||
      _importingQr ||
      _selectionUpdating ||
      _exportingSelection ||
      _deletingSelection;

  Future<void> _reloadRules() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    final rules = await _ruleStore.loadRules();
    final sorted = rules.toList()
      ..sort((a, b) {
        final bySort = a.sortNumber.compareTo(b.sortNumber);
        if (bySort != 0) return bySort;
        return a.name.compareTo(b.name);
      });
    if (!mounted) return;
    final availableNames = sorted.map((rule) => rule.name).toSet();
    setState(() {
      _rules = sorted;
      _selectedRuleNames.removeWhere((name) => !availableNames.contains(name));
      if (_rules.isEmpty) {
        _selectionMode = false;
        _selectedRuleNames.clear();
      }
      _loading = false;
    });
  }

  void _toggleSelectionMode() {
    if (_rules.isEmpty) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedRuleNames.clear();
    });
  }

  void _toggleRuleSelection(String ruleName) {
    setState(() {
      if (_selectedRuleNames.contains(ruleName)) {
        _selectedRuleNames.remove(ruleName);
      } else {
        _selectedRuleNames.add(ruleName);
      }
    });
  }

  void _toggleSelectAllRules() {
    final totalCount = _rules.length;
    if (totalCount == 0) return;
    setState(() {
      final allSelected = _selectedRuleNames.length == totalCount;
      if (allSelected) {
        _selectedRuleNames.clear();
      } else {
        _selectedRuleNames
          ..clear()
          ..addAll(_rules.map((rule) => rule.name));
      }
    });
  }

  void _revertSelection() {
    if (_rules.isEmpty) return;
    final allNames = _rules.map((rule) => rule.name).toSet();
    setState(() {
      final reverted = <String>{};
      for (final name in allNames) {
        if (!_selectedRuleNames.contains(name)) {
          reverted.add(name);
        }
      }
      _selectedRuleNames
        ..clear()
        ..addAll(reverted);
    });
  }

  Future<void> _openRuleEditor(DictRule rule) async {
    final savedRule = await Navigator.of(context).push<DictRule>(
      CupertinoPageRoute<DictRule>(
        builder: (_) => DictRuleEditView(initialRule: rule),
      ),
    );
    if (savedRule == null) return;
    try {
      await _ruleStore.saveRule(
        originalName: rule.name,
        newRule: savedRule,
      );
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('SaveDictRuleError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '字典规则',
        message: '保存失败：$error',
      );
    }
  }

  Future<void> _createRule() async {
    await _openRuleEditor(
      const DictRule(
        name: '',
        urlRule: '',
        showRule: '',
        enabled: true,
        sortNumber: 0,
      ),
    );
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showAppPopoverMenu<_DictRuleMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _DictRuleMenuAction.importLocal,
          icon: CupertinoIcons.doc,
          label: '本地导入',
        ),
        AppPopoverMenuItem(
          value: _DictRuleMenuAction.importOnline,
          icon: CupertinoIcons.globe,
          label: '网络导入',
        ),
        AppPopoverMenuItem(
          value: _DictRuleMenuAction.importQr,
          icon: CupertinoIcons.qrcode,
          label: '二维码导入',
        ),
        AppPopoverMenuItem(
          value: _DictRuleMenuAction.importDefault,
          icon: CupertinoIcons.wand_rays,
          label: '导入默认规则',
        ),
        AppPopoverMenuItem(
          value: _DictRuleMenuAction.help,
          icon: CupertinoIcons.question_circle,
          label: '帮助',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _DictRuleMenuAction.importDefault:
        await _importDefaultRules();
        return;
      case _DictRuleMenuAction.importLocal:
        await _importLocalRules();
        return;
      case _DictRuleMenuAction.importOnline:
        await _importOnlineRules();
        return;
      case _DictRuleMenuAction.importQr:
        await _importQrRules();
        return;
      case _DictRuleMenuAction.help:
        await _showDictRuleHelp();
        return;
    }
  }

  Future<void> _showSelectionMoreMenu() async {
    if (_menuBusy || _selectedRuleNames.isEmpty) return;
    final selected = await showAppPopoverMenu<_DictRuleSelectionMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _DictRuleSelectionMenuAction.enableSelection,
          icon: CupertinoIcons.check_mark,
          label: '启用所选',
        ),
        AppPopoverMenuItem(
          value: _DictRuleSelectionMenuAction.disableSelection,
          icon: CupertinoIcons.xmark,
          label: '禁用所选',
        ),
        AppPopoverMenuItem(
          value: _DictRuleSelectionMenuAction.exportSelection,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出所选',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _DictRuleSelectionMenuAction.enableSelection:
        await _enableSelectedRules();
        return;
      case _DictRuleSelectionMenuAction.disableSelection:
        await _disableSelectedRules();
        return;
      case _DictRuleSelectionMenuAction.exportSelection:
        await _exportSelectedRules();
        return;
    }
  }

  List<DictRule> _selectedRulesByCurrentOrder() {
    final selectedNames = _selectedRuleNames;
    if (selectedNames.isEmpty) return const <DictRule>[];
    return _rules
        .where((rule) => selectedNames.contains(rule.name))
        .toList(growable: false);
  }

  Future<void> _exportSelectedRules() async {
    if (_exportingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder();
    if (selectedRules.isEmpty) return;
    setState(() => _exportingSelection = true);
    try {
      final jsonText = DictRule.listToJsonText(selectedRules);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出所选',
        fileName: 'exportDictRule.json',
        allowedExtensions: const ['json'],
        text: jsonText,
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      final normalizedPath = outputPath.trim();
      if (!mounted) return;
      await _showExportPathDialog(normalizedPath);
    } catch (error, stackTrace) {
      debugPrint('ExportDictRuleSelectionError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导出所选',
        message: '导出失败：$error',
      );
    } finally {
      if (!mounted) return;
      setState(() => _exportingSelection = false);
    }
  }

  Future<void> _enableSelectedRules() async {
    if (_enablingSelection) return;
    if (_selectedRuleNames.isEmpty) return;
    setState(() => _enablingSelection = true);
    try {
      await _ruleStore.setEnabledForRuleNames(
        ruleNames: _selectedRuleNames,
        enabled: true,
      );
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('EnableSelectionDictRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _enablingSelection = false);
    }
  }

  Future<void> _disableSelectedRules() async {
    if (_disablingSelection) return;
    if (_selectedRuleNames.isEmpty) return;
    setState(() => _disablingSelection = true);
    try {
      await _ruleStore.setEnabledForRuleNames(
        ruleNames: _selectedRuleNames,
        enabled: false,
      );
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('DisableSelectionDictRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _disablingSelection = false);
    }
  }

  Future<void> _deleteSelectedRules() async {
    if (_deletingSelection) return;
    final selectedNames = _selectedRuleNames.toSet();
    if (selectedNames.isEmpty) return;
    setState(() => _deletingSelection = true);
    try {
      await _ruleStore.deleteRulesByNames(selectedNames);
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('DeleteSelectionDictRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _deletingSelection = false);
    }
  }

  Future<void> _showExportPathDialog(String outputPath) async {
    final path = outputPath.trim();
    if (path.isEmpty || !mounted) return;
    final uri = Uri.tryParse(path);
    final isHttpPath = uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    final lines = <String>[
      '导出路径：',
      path,
      if (isHttpPath) '',
      if (isHttpPath) '检测到网络链接，可直接复制后分享。',
    ];
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('复制路径'),
          ),
        ],
      ),
    );
  }

  Future<void> _importDefaultRules() async {
    if (_importingDefault) return;
    setState(() => _importingDefault = true);
    try {
      await _ruleStore.importDefaultRules();
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('ImportDefaultDictRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _importingDefault = false);
    }
  }

  Future<void> _importLocalRules() async {
    if (_importingLocal) return;
    setState(() => _importingLocal = true);
    try {
      final fileText = await _pickLocalImportText();
      if (fileText == null) {
        return;
      }
      await _importRulesFromInput(fileText);
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入字典规则',
        message: _formatImportError(error),
      );
    } finally {
      if (!mounted) return;
      setState(() => _importingLocal = false);
    }
  }

  Future<void> _importOnlineRules() async {
    if (_importingOnline) return;
    setState(() => _importingOnline = true);
    try {
      final rawInput = await _showOnlineImportInputSheet();
      final normalizedInput = rawInput?.trim();
      if (normalizedInput == null || normalizedInput.isEmpty) {
        return;
      }
      if (_isHttpUrl(normalizedInput)) {
        await _pushOnlineImportHistory(normalizedInput);
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入字典规则',
        message: _formatImportError(error),
      );
    } finally {
      if (!mounted) return;
      setState(() => _importingOnline = false);
    }
  }

  Future<void> _importQrRules() async {
    if (_importingQr) return;
    setState(() => _importingQr = true);
    try {
      final text = await QrScanService.scanText(
        context,
        title: '二维码导入',
      );
      final normalizedInput = text?.trim();
      if (normalizedInput == null || normalizedInput.isEmpty) {
        return;
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入字典规则',
        message: _formatImportError(error),
      );
    } finally {
      if (!mounted) return;
      setState(() => _importingQr = false);
    }
  }

  Future<void> _importRulesFromInput(String rawInput) async {
    final candidates = await _ruleStore.previewImportCandidates(rawInput);
    if (candidates.isEmpty) {
      await _showMessageDialog(
        title: '导入字典规则',
        message: '格式不对',
      );
      return;
    }
    if (!mounted) return;
    final selectedIndexes = await _showImportSelectionSheet(candidates);
    if (selectedIndexes == null || selectedIndexes.isEmpty) {
      return;
    }
    if (!mounted) return;
    await _runImportingTask(() async {
      await _ruleStore.importCandidates(
        candidates: candidates,
        selectedIndexes: selectedIndexes,
      );
    });
    await _reloadRules();
  }

  Future<String?> _showOnlineImportInputSheet() async {
    final history = await _loadOnlineImportHistory();
    final inputController = TextEditingController();
    try {
      return showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SizedBox(
              height: math.min(MediaQuery.of(context).size.height * 0.72, 560),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '网络导入',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(popupContext),
                              child: const Text('取消'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: inputController,
                                placeholder: 'url',
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              onPressed: () {
                                Navigator.pop(
                                  popupContext,
                                  inputController.text.trim(),
                                );
                              },
                              child: const Text('导入'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '历史记录',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: history.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无历史记录',
                                  style: TextStyle(
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                itemCount: history.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  return AppCard(
                                    backgroundColor: CupertinoColors.systemGrey6
                                        .resolveFrom(context),
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              inputController.text = item;
                                            },
                                            child: Text(
                                              item,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(28, 28),
                                          onPressed: () async {
                                            history.removeAt(index);
                                            await _saveOnlineImportHistory(
                                              history,
                                            );
                                            if (mounted) {
                                              setDialogState(() {});
                                            }
                                          },
                                          child: Icon(
                                            CupertinoIcons.delete,
                                            size: 18,
                                            color: CupertinoColors.systemRed
                                                .resolveFrom(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      inputController.dispose();
    }
  }

  bool _isHttpUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) return false;
    return parsed.scheme == 'http' || parsed.scheme == 'https';
  }

  Future<List<String>> _loadOnlineImportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final listValue = prefs.getStringList(_onlineImportHistoryKey);
    if (listValue != null) {
      return _normalizeOnlineImportHistory(listValue);
    }
    final textValue = prefs.getString(_onlineImportHistoryKey);
    if (textValue != null && textValue.trim().isNotEmpty) {
      return _normalizeOnlineImportHistory(
        textValue.split(RegExp(r'[\n,]')),
      );
    }
    return <String>[];
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeOnlineImportHistory(history);
    await prefs.setStringList(_onlineImportHistoryKey, normalized);
  }

  Future<void> _pushOnlineImportHistory(String url) async {
    final history = await _loadOnlineImportHistory();
    history.remove(url);
    history.insert(0, url);
    await _saveOnlineImportHistory(history);
  }

  List<String> _normalizeOnlineImportHistory(Iterable<String> values) {
    final unique = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !unique.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  String _formatImportError(Object error) {
    if (error is FileSystemException) {
      final message = error.message.trim();
      if (message.isEmpty) return 'readTextError:ERROR';
      return 'readTextError:$message';
    }
    if (error is FormatException) {
      final message = error.message.trim();
      if (message.isEmpty) return 'ImportError:格式不对';
      return 'ImportError:$message';
    }
    final text = '$error'.trim();
    if (text.isEmpty) return 'ImportError:ERROR';
    if (text.startsWith('Exception:')) {
      final stripped = text.substring('Exception:'.length).trim();
      return stripped.isEmpty ? 'ImportError:ERROR' : 'ImportError:$stripped';
    }
    return 'ImportError:$text';
  }

  Future<String?> _pickLocalImportText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!, allowMalformed: true);
    }
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      return File(path).readAsString();
    }
    throw const FileSystemException('无法读取文件内容');
  }

  Future<Set<int>?> _showImportSelectionSheet(
    List<DictRuleImportCandidate> candidates,
  ) async {
    final selectedIndexes = <int>{
      for (var index = 0; index < candidates.length; index++)
        if (candidates[index].selectedByDefault) index,
    };
    return showCupertinoBottomSheetDialog<Set<int>>(
      context: context,
      builder: (popupContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final selectedCount = selectedIndexes.length;
              final totalCount = candidates.length;
              final allSelected = totalCount > 0 && selectedCount == totalCount;
              final toggleAllLabel = allSelected
                  ? '取消全选（$selectedCount/$totalCount）'
                  : '全选（$selectedCount/$totalCount）';
              return SizedBox(
                height: math.min(
                  MediaQuery.of(context).size.height * 0.86,
                  680,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '导入字典规则',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => Navigator.pop(popupContext),
                            child: const Text('取消'),
                          ),
                          CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: selectedCount == 0
                                ? null
                                : () => Navigator.pop(
                                      popupContext,
                                      selectedIndexes.toSet(),
                                    ),
                            child: Text('导入($selectedCount)'),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: CupertinoColors.systemGrey5.resolveFrom(
                            context,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              if (allSelected) {
                                selectedIndexes.clear();
                              } else {
                                selectedIndexes
                                  ..clear()
                                  ..addAll(
                                    List<int>.generate(
                                      candidates.length,
                                      (index) => index,
                                    ),
                                  );
                              }
                            });
                          },
                          child: Text(toggleAllLabel),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: candidates.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final selected = selectedIndexes.contains(index);
                          return _DictRuleImportCandidateTile(
                            candidate: candidate,
                            selected: selected,
                            onTap: () {
                              setDialogState(() {
                                if (selected) {
                                  selectedIndexes.remove(index);
                                } else {
                                  selectedIndexes.add(index);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _runImportingTask(Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CupertinoAlertDialog(
        content: _BlockingProgressContent(text: '导入中...'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    try {
      await task();
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDictRuleHelp() async {
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/dictRuleHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!mounted) return;
      await _showMessageDialog(
        title: '帮助',
        message: '帮助文档加载失败：$error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedRuleNames.length;
    final totalCount = _rules.length;
    final hasSelection = selectedCount > 0;
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    return AppCupertinoPageScaffold(
      title: '配置字典规则',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_selectionMode)
            AppNavBarButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: _menuBusy ? null : _createRule,
              child: const Icon(CupertinoIcons.add),
            ),
          AppNavBarButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: _menuBusy || (!_selectionMode && _rules.isEmpty)
                ? null
                : _toggleSelectionMode,
            child: Text(
              _selectionMode ? '完成' : '多选',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          AppNavBarButton(
            key: _moreMenuKey,
            onPressed: _selectionMode
                ? (hasSelection && !_menuBusy ? _showSelectionMoreMenu : null)
                : (_menuBusy ? null : _showMoreMenu),
            child: _selectionMode
                ? (_selectionActionBusy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : Icon(
                        CupertinoIcons.ellipsis_circle,
                        color: hasSelection ? enabledColor : disabledColor,
                      ))
                : (_menuBusy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Icon(CupertinoIcons.ellipsis)),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Expanded(
                  child: AppListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    children: [
                      AppListSection(
                        header: const Text('字典规则'),
                        children: _rules.isEmpty
                            ? const [
                                CupertinoListTile.notched(
                                  title: Text('暂无规则'),
                                  subtitle: Text('点击右上角更多菜单本地导入、网络导入或二维码导入'),
                                ),
                              ]
                            : _rules.map((rule) {
                                final title = rule.name.trim().isEmpty
                                    ? '未命名规则'
                                    : rule.name.trim();
                                final subtitle = rule.urlRule.trim().isEmpty
                                    ? '未配置 URL 规则'
                                    : rule.urlRule.trim();
                                final selected =
                                    _selectedRuleNames.contains(rule.name);
                                final tile = CupertinoListTile.notched(
                                  title: Text(title),
                                  subtitle: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  additionalInfo:
                                      rule.enabled ? null : const Text('禁用'),
                                  trailing: _selectionMode
                                      ? Icon(
                                          selected
                                              ? CupertinoIcons
                                                  .check_mark_circled_solid
                                              : CupertinoIcons.circle,
                                          color: selected
                                              ? CupertinoColors.activeBlue
                                                  .resolveFrom(context)
                                              : CupertinoColors.secondaryLabel
                                                  .resolveFrom(context),
                                          size: 20,
                                        )
                                      : null,
                                  onTap: _selectionMode
                                      ? () => _toggleRuleSelection(rule.name)
                                      : () => _openRuleEditor(rule),
                                );
                                if (!_selectionMode || !selected) {
                                  return tile;
                                }
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey6
                                        .resolveFrom(context),
                                  ),
                                  child: tile,
                                );
                              }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
                if (_selectionMode)
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGroupedBackground
                            .resolveFrom(context),
                        border: Border(
                          top: BorderSide(
                            color: CupertinoColors.systemGrey4
                                .resolveFrom(context),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              minimumSize: const Size(30, 30),
                              alignment: Alignment.centerLeft,
                              onPressed: totalCount == 0
                                  ? null
                                  : _toggleSelectAllRules,
                              child: Text(
                                allSelected
                                    ? '取消全选（$selectedCount/$totalCount）'
                                    : '全选（$selectedCount/$totalCount）',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: totalCount == 0
                                      ? disabledColor
                                      : enabledColor,
                                ),
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: const Size(30, 30),
                            onPressed: hasSelection ? _revertSelection : null,
                            child: Text(
                              '反选',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    hasSelection ? enabledColor : disabledColor,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: const Size(30, 30),
                            onPressed: hasSelection && !_menuBusy
                                ? _deleteSelectedRules
                                : null,
                            child: _deletingSelection
                                ? const CupertinoActivityIndicator(radius: 9)
                                : Text(
                                    '删除',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: hasSelection && !_menuBusy
                                          ? CupertinoColors.systemRed
                                              .resolveFrom(context)
                                          : disabledColor,
                                    ),
                                  ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            minimumSize: const Size(30, 30),
                            onPressed: hasSelection && !_menuBusy
                                ? _showSelectionMoreMenu
                                : null,
                            child: _selectionActionBusy
                                ? const CupertinoActivityIndicator(radius: 9)
                                : Icon(
                                    CupertinoIcons.ellipsis_circle,
                                    size: 19,
                                    color: hasSelection
                                        ? enabledColor
                                        : disabledColor,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

enum _DictRuleMenuAction {
  importLocal,
  importOnline,
  importQr,
  importDefault,
  help,
}

enum _DictRuleSelectionMenuAction {
  enableSelection,
  disableSelection,
  exportSelection,
}

class _DictRuleImportCandidateTile extends StatelessWidget {
  const _DictRuleImportCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final DictRuleImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(candidate.state);
    final stateColor = _stateColor(context, candidate.state);
    final title = candidate.rule.name.trim().isEmpty
        ? '未命名规则'
        : candidate.rule.name.trim();
    final subtitle = candidate.rule.urlRule.trim().isEmpty
        ? '未配置 URL 规则'
        : candidate.rule.urlRule.trim();
    final backgroundColor = selected
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : CupertinoColors.systemBackground.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppCard(
        backgroundColor: backgroundColor,
        borderColor: CupertinoColors.separator.resolveFrom(context),
        borderWidth: 0.5,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: selected
                  ? CupertinoColors.activeBlue.resolveFrom(context)
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stateLabel(DictRuleImportCandidateState state) {
    return switch (state) {
      DictRuleImportCandidateState.newRule => '新增',
      DictRuleImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    DictRuleImportCandidateState state,
  ) {
    return switch (state) {
      DictRuleImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      DictRuleImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }
}

class _BlockingProgressContent extends StatelessWidget {
  const _BlockingProgressContent({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    );
  }
}
