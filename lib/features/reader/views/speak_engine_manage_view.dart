import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../models/http_tts_rule.dart';
import '../services/http_tts_rule_store.dart';
import 'http_tts_rule_edit_view.dart';


class SpeakEngineManageView extends StatefulWidget {
  const SpeakEngineManageView({super.key});

  @override
  State<SpeakEngineManageView> createState() => _SpeakEngineManageViewState();
}

class _SpeakEngineManageViewState extends State<SpeakEngineManageView> {
  static const String _onlineImportHistoryKey = 'ttsUrlKey';

  final HttpTtsRuleStore _ruleStore = HttpTtsRuleStore();
  final OnlineImportHistoryStore _onlineImportHistoryStore =
      OnlineImportHistoryStore();

  bool _loading = true;
  bool _importingDefault = false;
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _exporting = false;
  List<HttpTtsRule> _rules = const <HttpTtsRule>[];
  int? _selectedRuleId;

  @override
  void initState() {
    super.initState();
    _reloadRules();
  }

  bool get _menuBusy =>
      _importingDefault || _importingLocal || _importingOnline || _exporting;

  void _updateState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  void _setLoading(bool value) {
    _updateState(() => _loading = value);
  }

  void _setImportingDefault(bool value) {
    _updateState(() => _importingDefault = value);
  }

  void _setImportingLocal(bool value) {
    _updateState(() => _importingLocal = value);
  }

  void _setImportingOnline(bool value) {
    _updateState(() => _importingOnline = value);
  }

  void _setExporting(bool value) {
    _updateState(() => _exporting = value);
  }

  void _setRulesLoaded(List<HttpTtsRule> rules, int? selectedRuleId) {
    _updateState(() {
      _rules = rules;
      _selectedRuleId = selectedRuleId;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '朗读引擎',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: _menuBusy ? null : _addRule,
            child: const Icon(CupertinoIcons.add),
            minimumSize: const Size(30, 30),
          ),
          AppNavBarButton(
            onPressed: _menuBusy ? null : _showMoreMenu,
            child: _menuBusy
                ? const CupertinoActivityIndicator(radius: 9)
                : const Icon(CupertinoIcons.ellipsis),
            minimumSize: const Size(30, 30),
          ),
        ],
      ),
      child: _buildManageBody(),
    );
  }


  // --- from speak_engine_manage_actions_menu.dart ---
  Future<void> _reloadRules() async {
    _setLoading(true);
    final results = await Future.wait([
      _ruleStore.loadRules(),
      _ruleStore.loadSelectedRuleId(),
    ]);
    final rules = results[0] as List<HttpTtsRule>;
    final selectedId = results[1] as int?;
    final sorted = rules.toList()
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      });
    _setRulesLoaded(sorted, selectedId);
  }

  Future<void> _selectEngine(int? ruleId) async {
    await _ruleStore.saveSelectedRuleId(ruleId);
    _updateState(() => _selectedRuleId = ruleId);
    String name;
    if (ruleId == null) {
      name = '系统默认';
    } else {
      final matched = _rules.where((r) => r.id == ruleId).firstOrNull;
      final rawName = matched?.name.trim() ?? '';
      name = rawName.isEmpty ? '未命名引擎' : rawName;
    }
    _showToastMessage('已切换到 $name');
  }

  HttpTtsRule _buildNewRuleDraft() {
    final usedIds = _rules.map((rule) => rule.id).toSet();
    var id = DateTime.now().millisecondsSinceEpoch;
    while (usedIds.contains(id)) {
      id++;
    }
    return HttpTtsRule(
      id: id,
      name: '',
      url: '',
      contentType: null,
      concurrentRate: '0',
      loginUrl: null,
      loginUi: null,
      header: null,
      jsLib: null,
      enabledCookieJar: false,
      loginCheckJs: null,
      lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _openRuleEditor(HttpTtsRule rule) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => HttpTtsRuleEditView(
          initialRule: rule,
          onRuleSaved: (_) {
            _reloadRules();
          },
        ),
      ),
    );
  }

  Future<void> _deleteRule(HttpTtsRule rule) async {
    try {
      await _ruleStore.deleteRule(rule.id);
      await _reloadRules();
    } catch (_) {}
  }

  Future<void> _addRule() async {
    if (_menuBusy) return;
    await _openRuleEditor(_buildNewRuleDraft());
  }

  Future<void> _importDefaultRules() async {
    if (_importingDefault) return;
    _setImportingDefault(true);
    try {
      await _ruleStore.importDefaultRules();
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showCupertinoBottomDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('导入默认规则'),
          content: Text('导入失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } finally {
      _setImportingDefault(false);
    }
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showAppActionListSheet<_SpeakEngineMenuAction>(
      context: context,
      title: '朗读引擎',
      showCancel: true,
      items: const [
        AppActionListItem<_SpeakEngineMenuAction>(
          value: _SpeakEngineMenuAction.importDefaultRules,
          icon: CupertinoIcons.arrow_down_doc,
          label: '导入默认规则',
        ),
        AppActionListItem<_SpeakEngineMenuAction>(
          value: _SpeakEngineMenuAction.importLocal,
          icon: CupertinoIcons.folder,
          label: '本地导入',
        ),
        AppActionListItem<_SpeakEngineMenuAction>(
          value: _SpeakEngineMenuAction.importOnline,
          icon: CupertinoIcons.cloud_download,
          label: '网络导入',
        ),
        AppActionListItem<_SpeakEngineMenuAction>(
          value: _SpeakEngineMenuAction.export,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _SpeakEngineMenuAction.importDefaultRules:
        await _importDefaultRules();
        return;
      case _SpeakEngineMenuAction.importLocal:
        await _importLocalRules();
        return;
      case _SpeakEngineMenuAction.importOnline:
        await _importOnlineRules();
        return;
      case _SpeakEngineMenuAction.export:
        await _exportRules();
        return;
    }
  }

  Future<void> _exportRules() async {
    if (_exporting) return;
    _setExporting(true);
    try {
      final jsonText = HttpTtsRule.listToJsonText(_rules);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出',
        fileName: 'httpTts.json',
        allowedExtensions: const ['json'],
        text: jsonText,
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      final normalizedPath = outputPath.trim();
      if (!mounted) return;
      await _showExportPathDialog(normalizedPath);
    } catch (error) {
      if (!mounted) return;
      await _showMessageDialog(
        title: '导出',
        message: '导出失败：$error',
      );
    } finally {
      _setExporting(false);
    }
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

  Future<void> _showExportPathDialog(String outputPath) async {
    final path = outputPath.trim();
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
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              _showToastMessage('已复制导出路径');
            },
            child: const Text('复制路径'),
          ),
        ],
      ),
    );
  }

  void _showToastMessage(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  // --- from speak_engine_manage_actions_import.dart ---
  Future<void> _importLocalRules() async {
    if (_importingLocal) return;
    _setImportingLocal(true);
    try {
      final fileText = await _pickLocalImportText();
      if (fileText == null) {
        return;
      }
      final candidates = await _ruleStore.previewImportCandidates(fileText);
      if (candidates.isEmpty) {
        await _showMessageDialog(
          title: '本地导入',
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
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '本地导入',
        message: '导入失败：$error',
      );
    } finally {
      _setImportingLocal(false);
    }
  }

  Future<void> _importOnlineRules() async {
    if (_importingOnline) return;
    _setImportingOnline(true);
    try {
      final rawInput = await _showOnlineImportInputSheet();
      final normalizedInput = rawInput?.trim();
      if (normalizedInput == null || normalizedInput.isEmpty) {
        return;
      }
      if (_isHttpUrl(normalizedInput)) {
        await _pushOnlineImportHistory(normalizedInput);
      }
      final candidates = await _ruleStore.previewImportCandidates(
        normalizedInput,
      );
      if (candidates.isEmpty) {
        await _showMessageDialog(
          title: '网络导入',
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
    } on FormatException {
      if (!mounted) return;
      await _showMessageDialog(
        title: '网络导入',
        message: '格式不对',
      );
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '网络导入',
        message: '导入失败：$error',
      );
    } finally {
      _setImportingOnline(false);
    }
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
    List<HttpTtsImportCandidate> candidates,
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
                  ? '取消全选($selectedCount/$totalCount)'
                  : '全选($selectedCount/$totalCount)';
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
                              '导入朗读引擎',
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
                          color: CupertinoColors.systemGrey5.resolveFrom(context),
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
                          return _ImportCandidateTile(
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

  // --- from speak_engine_manage_actions_import_history.dart ---
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
                                      color: CupertinoColors.systemGrey6.resolveFrom(context),
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
                                            color: CupertinoColors.systemRed.resolveFrom(context)
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
    return _onlineImportHistoryStore.load(
      _SpeakEngineManageViewState._onlineImportHistoryKey,
    );
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    await _onlineImportHistoryStore.save(
      _SpeakEngineManageViewState._onlineImportHistoryKey,
      history,
    );
  }

  Future<void> _pushOnlineImportHistory(String url) async {
    await _onlineImportHistoryStore.push(
      _SpeakEngineManageViewState._onlineImportHistoryKey,
      url,
    );
  }

  // --- from speak_engine_manage_ui.dart ---
  Widget _buildManageBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final tokens = AppUiTokens.resolve(context);
    return AppListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        _buildSectionHeader(tokens, '系统引擎'),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListTile(
            title: const Text('系统默认'),
            subtitle: const Text('跟随设备 TTS 设置'),
            showChevron: false,
            onTap: () => _selectEngine(null),
            additionalInfo: _selectedRuleId == null
                ? Icon(
                    CupertinoIcons.checkmark_alt,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                    size: 18,
                  )
                : null,
          ),
        ),
        if (_rules.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: AppEmptyState(
              illustration: AppEmptyPlanetIllustration(size: 86),
              title: '暂无规则',
              message: '点击右上角添加，或从更多菜单导入默认规则。',
            ),
          )
        else
          _buildRuleSection(tokens),
      ],
    );
  }

  Widget _buildRuleSection(AppUiTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildSectionHeader(tokens, 'HTTP 朗读引擎'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < _rules.length; i++) ...[
                _buildRuleTile(_rules[i]),
                if (i < _rules.length - 1) _buildDivider(tokens),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleTile(HttpTtsRule rule) {
    final fallbackTitle = rule.url.trim().isEmpty ? '未命名引擎' : rule.url.trim();
    final title = rule.name.trim().isEmpty ? fallbackTitle : rule.name.trim();
    final subtitle = rule.url.trim().isEmpty ? '未配置 URL' : rule.url.trim();
    final isSelected = _selectedRuleId == rule.id;
    return AppListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      additionalInfo: isSelected
          ? Icon(
              CupertinoIcons.checkmark_alt,
              color: CupertinoColors.activeBlue.resolveFrom(context),
              size: 18,
            )
          : rule.isDefaultRule
              ? const Text('默认')
              : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(36, 36),
            onPressed: () => _openRuleEditor(rule),
            child: Icon(
              CupertinoIcons.pencil,
              size: 18,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(left: 2, right: 2),
            minimumSize: const Size(36, 36),
            onPressed: () => _deleteRule(rule),
            child: Icon(
              CupertinoIcons.delete,
              size: 18,
              color: CupertinoColors.destructiveRed.resolveFrom(context),
            ),
          ),
        ],
      ),
      showChevron: false,
      onTap: () => _selectEngine(rule.id),
    );
  }

  Widget _buildSectionHeader(AppUiTokens tokens, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: tokens.colors.secondaryLabel,
        ),
      ),
    );
  }

  Widget _buildDivider(AppUiTokens tokens) {
    return Container(
      height: tokens.sizes.dividerThickness,
      color: tokens.colors.separator.withValues(alpha: 0.72),
    );
  }
}

enum _SpeakEngineMenuAction {
  importDefaultRules,
  importLocal,
  importOnline,
  export,
}

class _ImportCandidateTile extends StatelessWidget {
  const _ImportCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final HttpTtsImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(candidate.state);
    final stateColor = _stateColor(context, candidate.state);
    final name = candidate.rule.name.trim();
    final url = candidate.rule.url.trim();
    final title = name.isEmpty ? (url.isEmpty ? '未命名引擎' : url) : name;
    final subtitle = url.isEmpty ? '未配置 URL' : url;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppCard(
        backgroundColor: selected
            ? CupertinoColors.systemGrey5.resolveFrom(context)
            : CupertinoColors.systemBackground.resolveFrom(context),
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
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
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

  static String _stateLabel(HttpTtsImportCandidateState state) {
    return switch (state) {
      HttpTtsImportCandidateState.newRule => '新增',
      HttpTtsImportCandidateState.update => '更新',
      HttpTtsImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    HttpTtsImportCandidateState state,
  ) {
    return switch (state) {
      HttpTtsImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      HttpTtsImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      HttpTtsImportCandidateState.existing =>
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
