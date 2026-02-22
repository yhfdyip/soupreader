import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import 'http_tts_rule_edit_view.dart';
import '../models/http_tts_rule.dart';
import '../services/http_tts_rule_store.dart';

class SpeakEngineManageView extends StatefulWidget {
  const SpeakEngineManageView({super.key});

  @override
  State<SpeakEngineManageView> createState() => _SpeakEngineManageViewState();
}

class _SpeakEngineManageViewState extends State<SpeakEngineManageView> {
  static const String _onlineImportHistoryKey = 'ttsUrlKey';

  final HttpTtsRuleStore _ruleStore = HttpTtsRuleStore();

  bool _loading = true;
  bool _importingDefault = false;
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _exporting = false;
  List<HttpTtsRule> _rules = const <HttpTtsRule>[];

  @override
  void initState() {
    super.initState();
    _reloadRules();
  }

  bool get _menuBusy =>
      _importingDefault || _importingLocal || _importingOnline || _exporting;

  Future<void> _reloadRules() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    final rules = await _ruleStore.loadRules();
    final sorted = rules.toList()
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      });
    if (!mounted) return;
    setState(() {
      _rules = sorted;
      _loading = false;
    });
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

  Future<void> _addRule() async {
    if (_menuBusy) return;
    await _openRuleEditor(_buildNewRuleDraft());
  }

  Future<void> _importDefaultRules() async {
    if (_importingDefault) return;
    setState(() => _importingDefault = true);
    try {
      await _ruleStore.importDefaultRules();
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
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
      if (!mounted) return;
      setState(() => _importingDefault = false);
    }
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showCupertinoModalPopup<_SpeakEngineMenuAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('朗读引擎'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _SpeakEngineMenuAction.importDefaultRules,
            ),
            child: const Text('导入默认规则'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _SpeakEngineMenuAction.importLocal,
            ),
            child: const Text('本地导入'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _SpeakEngineMenuAction.importOnline,
            ),
            child: const Text('网络导入'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _SpeakEngineMenuAction.export,
            ),
            child: const Text('导出'),
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
    setState(() => _exporting = true);
    try {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出',
        fileName: 'httpTts.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      final normalizedPath = outputPath.trim();
      final jsonText = HttpTtsRule.listToJsonText(_rules);
      await File(normalizedPath).writeAsString(jsonText, flush: true);
      if (!mounted) return;
      await _showExportPathDialog(normalizedPath);
    } catch (error) {
      if (!mounted) return;
      await _showMessageDialog(
        title: '导出',
        message: '导出失败：$error',
      );
    } finally {
      if (!mounted) return;
      setState(() => _exporting = false);
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
      if (!mounted) return;
      setState(() => _importingOnline = false);
    }
  }

  Future<String?> _showOnlineImportInputSheet() async {
    final history = await _loadOnlineImportHistory();
    final inputController = TextEditingController();
    try {
      return showCupertinoModalPopup<String>(
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
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGrey6
                                          .resolveFrom(context),
                                      borderRadius: BorderRadius.circular(10),
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
                                          child: const Icon(
                                            CupertinoIcons.delete,
                                            size: 18,
                                            color: CupertinoColors.systemRed,
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
    return showCupertinoModalPopup<Set<int>>(
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
    await showCupertinoDialog<void>(
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
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        });
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context)
                    .withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '朗读引擎',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 30,
            onPressed: _menuBusy ? null : _addRule,
            child: const Icon(CupertinoIcons.add),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 30,
            onPressed: _menuBusy ? null : _showMoreMenu,
            child: _menuBusy
                ? const CupertinoActivityIndicator(radius: 9)
                : const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('系统引擎'),
                  children: [
                    CupertinoListTile.notched(
                      title: const Text('系统默认'),
                      subtitle: const Text('跟随设备 TTS 设置'),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('HTTP 朗读引擎'),
                  children: _rules.isEmpty
                      ? const [
                          CupertinoListTile.notched(
                            title: Text('暂无规则'),
                            subtitle: Text('点击右上角添加或更多菜单导入默认规则'),
                          ),
                        ]
                      : _rules.map((rule) {
                          final fallbackTitle = rule.url.trim().isEmpty
                              ? '未命名引擎'
                              : rule.url.trim();
                          final title = rule.name.trim().isEmpty
                              ? fallbackTitle
                              : rule.name.trim();
                          final subtitle = rule.url.trim().isEmpty
                              ? '未配置 URL'
                              : rule.url.trim();
                          return CupertinoListTile.notched(
                            title: Text(title),
                            subtitle: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            additionalInfo:
                                rule.isDefaultRule ? const Text('默认') : null,
                            onTap: () async {
                              await _openRuleEditor(rule);
                            },
                          );
                        }).toList(growable: false),
                ),
              ],
            ),
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? CupertinoColors.systemGrey5.resolveFrom(context)
              : CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        child: Padding(
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
                  color: stateColor.withOpacity(0.14),
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
