import '../../../app/theme/design_tokens.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../../settings/views/app_help_dialog.dart';
import '../models/txt_toc_rule.dart';
import '../services/txt_toc_rule_store.dart';
import 'txt_toc_rule_edit_view.dart';

class TxtTocRuleManageView extends StatefulWidget {
  const TxtTocRuleManageView({super.key});

  @override
  State<TxtTocRuleManageView> createState() => _TxtTocRuleManageViewState();
}

class _TxtTocRuleManageViewState extends State<TxtTocRuleManageView> {
  static const String _onlineImportHistoryKey = 'tocRuleUrl';
  static const String _defaultOnlineImportUrl =
      'https://gitee.com/fisher52/YueDuJson/raw/master/myTxtChapterRule.json';

  final TxtTocRuleStore _ruleStore = TxtTocRuleStore();
  final GlobalKey _moreMenuKey = GlobalKey();
  final OnlineImportHistoryStore _onlineImportHistoryStore =
      OnlineImportHistoryStore();

  bool _loading = true;
  bool _importingDefault = false;
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _importingQr = false;
  bool _exportingSelection = false;
  bool _enablingSelection = false;
  bool _disablingSelection = false;
  bool _reorderingRule = false;
  bool _deletingRule = false;
  bool _selectionMode = false;
  List<TxtTocRule> _rules = const <TxtTocRule>[];
  final Set<int> _selectedRuleIds = <int>{};

  bool get _selectionUpdating => _enablingSelection || _disablingSelection;

  bool get _selectionActionBusy =>
      _selectionUpdating || _exportingSelection || _deletingRule;

  bool get _menuBusy =>
      _importingDefault ||
      _importingLocal ||
      _importingOnline ||
      _importingQr ||
      _exportingSelection ||
      _selectionUpdating ||
      _reorderingRule ||
      _deletingRule;

  @override
  void initState() {
    super.initState();
    _reloadRules();
  }

  Future<void> _reloadRules() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    final rules = await _ruleStore.loadRules();
    if (!mounted) return;
    final availableIds = rules.map((rule) => rule.id).toSet();
    setState(() {
      _rules = rules;
      _selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
      if (_rules.isEmpty) {
        _selectionMode = false;
        _selectedRuleIds.clear();
      }
      _loading = false;
    });
  }

  void _toggleSelectionMode() {
    if (_rules.isEmpty) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedRuleIds.clear();
    });
  }

  void _toggleRuleSelection(int ruleId) {
    setState(() {
      if (_selectedRuleIds.contains(ruleId)) {
        _selectedRuleIds.remove(ruleId);
      } else {
        _selectedRuleIds.add(ruleId);
      }
    });
  }

  void _toggleSelectAllRules() {
    final totalCount = _rules.length;
    if (totalCount == 0) return;
    setState(() {
      final allSelected = _selectedRuleIds.length == totalCount;
      if (allSelected) {
        _selectedRuleIds.clear();
      } else {
        _selectedRuleIds
          ..clear()
          ..addAll(_rules.map((rule) => rule.id));
      }
    });
  }

  void _revertSelection() {
    if (_rules.isEmpty) return;
    final allIds = _rules.map((rule) => rule.id).toSet();
    setState(() {
      final reverted = <int>{};
      for (final id in allIds) {
        if (!_selectedRuleIds.contains(id)) {
          reverted.add(id);
        }
      }
      _selectedRuleIds
        ..clear()
        ..addAll(reverted);
    });
  }

  Future<void> _openRuleEditor(TxtTocRule rule) async {
    final savedRule = await Navigator.of(context).push<TxtTocRule>(
      CupertinoPageRoute<TxtTocRule>(
        builder: (_) => TxtTocRuleEditView(initialRule: rule),
      ),
    );
    if (savedRule == null) return;
    try {
      await _ruleStore.upsertRule(savedRule);
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('SaveTxtTocRuleError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: 'TXT 目录规则',
        message: '保存失败：$error',
      );
    }
  }

  Future<void> _startAddRule() async {
    final draftRule = await _ruleStore.createDraftRule();
    if (!mounted) return;
    await _openRuleEditor(draftRule);
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showAppPopoverMenu<_TxtTocRuleMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _TxtTocRuleMenuAction.importLocal,
          icon: CupertinoIcons.doc,
          label: '本地导入',
        ),
        AppPopoverMenuItem(
          value: _TxtTocRuleMenuAction.importOnline,
          icon: CupertinoIcons.globe,
          label: '网络导入',
        ),
        AppPopoverMenuItem(
          value: _TxtTocRuleMenuAction.importQr,
          icon: CupertinoIcons.qrcode,
          label: '二维码导入',
        ),
        AppPopoverMenuItem(
          value: _TxtTocRuleMenuAction.importDefault,
          icon: CupertinoIcons.wand_rays,
          label: '导入默认规则',
        ),
        AppPopoverMenuItem(
          value: _TxtTocRuleMenuAction.help,
          icon: CupertinoIcons.question_circle,
          label: '帮助',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _TxtTocRuleMenuAction.importDefault:
        await _importDefaultRules();
        return;
      case _TxtTocRuleMenuAction.importLocal:
        await _importLocalRules();
        return;
      case _TxtTocRuleMenuAction.importOnline:
        await _importOnlineRules();
        return;
      case _TxtTocRuleMenuAction.importQr:
        await _importQrRules();
        return;
      case _TxtTocRuleMenuAction.help:
        await _showTxtTocRuleHelp();
        return;
    }
  }

  Future<void> _showSelectionMoreMenu() async {
    if (_menuBusy || _selectedRuleIds.isEmpty) return;
    final selected = await showAppPopoverMenu<_TxtTocRuleSelectionMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _TxtTocRuleSelectionMenuAction.enableSelection,
          icon: CupertinoIcons.check_mark,
          label: '启用所选',
        ),
        AppPopoverMenuItem(
          value: _TxtTocRuleSelectionMenuAction.disableSelection,
          icon: CupertinoIcons.xmark,
          label: '禁用所选',
        ),
        AppPopoverMenuItem(
          value: _TxtTocRuleSelectionMenuAction.exportSelection,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出所选',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _TxtTocRuleSelectionMenuAction.enableSelection:
        await _enableSelectedRules();
        return;
      case _TxtTocRuleSelectionMenuAction.disableSelection:
        await _disableSelectedRules();
        return;
      case _TxtTocRuleSelectionMenuAction.exportSelection:
        await _exportSelectedRules();
        return;
    }
  }

  Future<void> _showRuleItemMenu(TxtTocRule rule) async {
    if (_menuBusy || _selectionMode) return;
    final selected = await showCupertinoBottomDialog<_TxtTocRuleItemMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(rule.name.trim().isEmpty ? '未命名规则' : rule.name.trim()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _TxtTocRuleItemMenuAction.top,
            ),
            child: const Text('置顶'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _TxtTocRuleItemMenuAction.bottom,
            ),
            child: const Text('置底'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(
              sheetContext,
              _TxtTocRuleItemMenuAction.delete,
            ),
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    switch (selected) {
      case _TxtTocRuleItemMenuAction.top:
        await _moveRuleToTop(rule);
        return;
      case _TxtTocRuleItemMenuAction.bottom:
        await _moveRuleToBottom(rule);
        return;
      case _TxtTocRuleItemMenuAction.delete:
        if (_selectedRuleIds.remove(rule.id)) {
          setState(() {});
        }
        await _confirmDeleteRule(rule);
        return;
    }
  }

  Future<void> _confirmDeleteRule(TxtTocRule rule) async {
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n${rule.name}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _deleteRule(rule);
  }

  Future<void> _deleteRule(TxtTocRule rule) async {
    if (_deletingRule) return;
    setState(() => _deletingRule = true);
    try {
      await _ruleStore.deleteRule(rule.id);
      final rules = await _ruleStore.loadRules();
      if (!mounted) return;
      final availableIds = rules.map((item) => item.id).toSet();
      setState(() {
        _rules = rules;
        _selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
        if (_rules.isEmpty) {
          _selectionMode = false;
          _selectedRuleIds.clear();
        }
      });
    } catch (error, stackTrace) {
      debugPrint('DeleteTxtTocRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _deletingRule = false);
    }
  }

  Future<void> _confirmDeleteSelectedRules() async {
    final selectedIds = _selectedRuleIds.toSet();
    if (selectedIds.isEmpty) return;
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: const Text('是否确认删除？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _deleteSelectedRules(selectedIds);
  }

  Future<void> _deleteSelectedRules(Set<int> selectedIds) async {
    if (_deletingRule || selectedIds.isEmpty) return;
    setState(() => _deletingRule = true);
    try {
      await _ruleStore.deleteRulesByIds(selectedIds);
      final rules = await _ruleStore.loadRules();
      if (!mounted) return;
      final availableIds = rules.map((item) => item.id).toSet();
      setState(() {
        _rules = rules;
        _selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
        if (_rules.isEmpty) {
          _selectionMode = false;
          _selectedRuleIds.clear();
        }
      });
    } catch (error, stackTrace) {
      debugPrint('DeleteSelectionTxtTocRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _deletingRule = false);
    }
  }

  Future<void> _moveRuleToTop(TxtTocRule rule) async {
    if (_reorderingRule) return;
    setState(() => _reorderingRule = true);
    try {
      await _ruleStore.moveRuleToTop(rule);
      final rules = await _ruleStore.loadRules();
      if (!mounted) return;
      final availableIds = rules.map((item) => item.id).toSet();
      setState(() {
        _rules = rules;
        _selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
        if (_rules.isEmpty) {
          _selectionMode = false;
          _selectedRuleIds.clear();
        }
      });
    } catch (error, stackTrace) {
      debugPrint('TopTxtTocRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _reorderingRule = false);
    }
  }

  Future<void> _moveRuleToBottom(TxtTocRule rule) async {
    if (_reorderingRule) return;
    setState(() => _reorderingRule = true);
    try {
      await _ruleStore.moveRuleToBottom(rule);
      final rules = await _ruleStore.loadRules();
      if (!mounted) return;
      final availableIds = rules.map((item) => item.id).toSet();
      setState(() {
        _rules = rules;
        _selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
        if (_rules.isEmpty) {
          _selectionMode = false;
          _selectedRuleIds.clear();
        }
      });
    } catch (error, stackTrace) {
      debugPrint('BottomTxtTocRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _reorderingRule = false);
    }
  }

  List<TxtTocRule> _selectedRulesByCurrentOrder() {
    final selectedIds = _selectedRuleIds;
    if (selectedIds.isEmpty) return const <TxtTocRule>[];
    return _rules
        .where((rule) => selectedIds.contains(rule.id))
        .toList(growable: false);
  }

  Future<void> _enableSelectedRules() async {
    if (_selectionUpdating) return;
    if (_selectedRuleIds.isEmpty) return;
    setState(() => _enablingSelection = true);
    try {
      await _ruleStore.enableRulesByIds(_selectedRuleIds);
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('EnableSelectionTxtTocRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _enablingSelection = false);
    }
  }

  Future<void> _disableSelectedRules() async {
    if (_selectionUpdating) return;
    if (_selectedRuleIds.isEmpty) return;
    setState(() => _disablingSelection = true);
    try {
      await _ruleStore.disableRulesByIds(_selectedRuleIds);
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('DisableSelectionTxtTocRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _disablingSelection = false);
    }
  }

  Future<void> _exportSelectedRules() async {
    if (_exportingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder();
    if (selectedRules.isEmpty) return;
    setState(() => _exportingSelection = true);
    try {
      final jsonText = TxtTocRule.listToJsonText(selectedRules);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出所选',
        fileName: 'exportTxtTocRule.json',
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
      debugPrint('ExportTxtTocRuleSelectionError:$error');
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
    await showCupertinoBottomDialog<void>(
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
      debugPrint('ImportDefaultTxtTocRuleError:$error');
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
      debugPrint('ImportTxtTocRuleLocalError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入 TXT 目录规则',
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
      debugPrint('ImportTxtTocRuleOnlineError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入 TXT 目录规则',
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
      debugPrint('ImportTxtTocRuleQrError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入 TXT 目录规则',
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
        title: '导入 TXT 目录规则',
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

  Future<String?> _pickLocalImportText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['txt', 'json'],
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
    List<TxtTocRuleImportCandidate> candidates,
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
                  MediaQuery.sizeOf(context).height * 0.86,
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
                              '导入 TXT 目录规则',
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
                          return _TxtTocRuleImportCandidateTile(
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

  Future<String?> _showOnlineImportInputSheet() async {
    final persistedHistory = await _loadOnlineImportHistory();
    final history = _buildHistoryWithDefaultUrl(persistedHistory);
    final inputController = TextEditingController();
    try {
      return showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SizedBox(
              height: math.min(MediaQuery.sizeOf(context).height * 0.72, 560),
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
                            ? const AppEmptyState(
                                illustration:
                                    AppEmptyPlanetIllustration(size: 76),
                                title: '暂无历史记录',
                                message: '输入 URL 并导入后会自动保存',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                itemCount: history.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGrey6
                                          .resolveFrom(context),
                                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
                                    ),
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
    final scheme = parsed.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<List<String>> _loadOnlineImportHistory() async {
    return _onlineImportHistoryStore.load(_onlineImportHistoryKey);
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    await _onlineImportHistoryStore.save(_onlineImportHistoryKey, history);
  }

  Future<void> _pushOnlineImportHistory(String url) async {
    await _onlineImportHistoryStore.push(_onlineImportHistoryKey, url);
  }

  List<String> _buildHistoryWithDefaultUrl(Iterable<String> values) {
    final merged = <String>[_defaultOnlineImportUrl, ...values];
    return _onlineImportHistoryStore.normalize(merged);
  }

  Future<void> _runImportingTask(Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoBottomDialog<void>(
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
    await showCupertinoBottomDialog<void>(
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

  Future<void> _showTxtTocRuleHelp() async {
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/txtTocRuleHelp.md');
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

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedRuleIds.length;
    final totalCount = _rules.length;
    final hasSelection = selectedCount > 0;
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    return AppCupertinoPageScaffold(
      title: 'TXT 目录规则',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(30, 30),
            onPressed: _menuBusy || _selectionMode ? null : _startAddRule,
            child: const Text(
              '添加',
              style: TextStyle(fontSize: 13),
            ),
          ),
          AppNavBarButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(30, 30),
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
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _selectionMode
                ? (hasSelection && !_menuBusy ? _showSelectionMoreMenu : null)
                : (_menuBusy ? null : _showMoreMenu),
            child: _selectionMode
                ? (_selectionActionBusy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : Icon(
                        CupertinoIcons.line_horizontal_3,
                        size: 20,
                        color: hasSelection ? enabledColor : disabledColor,
                      ))
                : (_menuBusy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Icon(CupertinoIcons.line_horizontal_3, size: 20)),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Expanded(
                  child: _rules.isEmpty
                      ? _empty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          itemCount: _rules.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final rule = _rules[index];
                            final selected = _selectedRuleIds.contains(rule.id);
                            return _TxtTocRuleListTile(
                              rule: rule,
                              selectionMode: _selectionMode,
                              selected: selected,
                              onTap: _selectionMode
                                  ? () => _toggleRuleSelection(rule.id)
                                  : () => _openRuleEditor(rule),
                              onShowItemMenu: _selectionMode
                                  ? null
                                  : () => _showRuleItemMenu(rule),
                            );
                          },
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
                                ? _confirmDeleteSelectedRules
                                : null,
                            child: _deletingRule
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
                                    CupertinoIcons.line_horizontal_3,
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

  Widget _empty() {
    return const AppEmptyState(
      illustration: AppEmptyPlanetIllustration(size: 86),
      title: '暂无目录规则',
      message: '可点击右上角添加，或从本地导入、网络导入、二维码导入。',
    );
  }
}

class _TxtTocRuleListTile extends StatelessWidget {
  const _TxtTocRuleListTile({
    required this.rule,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onShowItemMenu,
  });

  final TxtTocRule rule;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onShowItemMenu;

  @override
  Widget build(BuildContext context) {
    final cardColor = selected
        ? CupertinoColors.systemGrey6.resolveFrom(context)
        : CupertinoColors.systemBackground.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectionMode) ...[
                  Icon(
                    selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    size: 20,
                    color: selected
                        ? CupertinoColors.activeBlue.resolveFrom(context)
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    rule.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!rule.enabled)
                  Text(
                    '已禁用',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemRed.resolveFrom(context),
                    ),
                  ),
                if (!selectionMode)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(28, 28),
                    onPressed: onShowItemMenu,
                    child: const Icon(
                      CupertinoIcons.line_horizontal_3,
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rule.rule,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: secondary,
              ),
            ),
            if ((rule.example ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '示例：${rule.example!.trim()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TxtTocRuleImportCandidateTile extends StatelessWidget {
  const _TxtTocRuleImportCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final TxtTocRuleImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemGrey6.resolveFrom(context);
    final state = _buildStateText(candidate.state);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusToast),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.scale(
              scale: 0.95,
              child: CupertinoSwitch(
                value: selected,
                onChanged: (_) => onTap(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.rule.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    candidate.rule.rule,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              state,
              style: TextStyle(
                fontSize: 12,
                color: _buildStateColor(context, candidate.state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildStateText(TxtTocRuleImportCandidateState state) {
    switch (state) {
      case TxtTocRuleImportCandidateState.newRule:
        return '新增';
      case TxtTocRuleImportCandidateState.update:
        return '更新';
      case TxtTocRuleImportCandidateState.existing:
        return '已有';
    }
  }

  Color _buildStateColor(
    BuildContext context,
    TxtTocRuleImportCandidateState state,
  ) {
    switch (state) {
      case TxtTocRuleImportCandidateState.newRule:
        return CupertinoColors.activeGreen.resolveFrom(context);
      case TxtTocRuleImportCandidateState.update:
        return CupertinoColors.activeBlue.resolveFrom(context);
      case TxtTocRuleImportCandidateState.existing:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TxtTocRuleMenuAction {
  importDefault,
  importLocal,
  importOnline,
  importQr,
  help,
}

enum _TxtTocRuleItemMenuAction {
  top,
  bottom,
  delete,
}

enum _TxtTocRuleSelectionMenuAction {
  enableSelection,
  disableSelection,
  exportSelection,
}
