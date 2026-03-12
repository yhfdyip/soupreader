import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../services/reader_source_switch_helper.dart';

Future<ReaderSourceSwitchCandidate?> showSourceSwitchCandidateSheet({
  required BuildContext context,
  required String keyword,
  required List<ReaderSourceSwitchCandidate> candidates,
  String currentSourceUrl = '',
  String changeSourceGroup = '',
  List<String> sourceGroups = const <String>[],
  String authorKeyword = '',
  bool checkAuthorEnabled = false,
  bool loadInfoEnabled = false,
  bool loadWordCountEnabled = false,
  bool loadTocEnabled = false,
  int changeSourceDelaySeconds = 0,
  Future<void> Function(bool enabled)? onCheckAuthorChanged,
  Future<void> Function(bool enabled)? onLoadInfoChanged,
  Future<void> Function(bool enabled)? onLoadWordCountChanged,
  Future<void> Function(bool enabled)? onLoadTocChanged,
  Future<void> Function(int seconds)? onChangeSourceDelayChanged,
  Future<void> Function(String group)? onChangeSourceGroupChanged,
  Future<void> Function()? onOpenSourceManage,
  Future<List<ReaderSourceSwitchCandidate>> Function(
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onStartCandidatesSearch,
  Future<void> Function()? onStopCandidatesSearch,
  Future<List<ReaderSourceSwitchCandidate>> Function(
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onRefreshCandidates,
  Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onTopSourceCandidate,
  Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onEditSourceCandidate,
  Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onBottomSourceCandidate,
  Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onDisableSourceCandidate,
  Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onDeleteSourceCandidate,
  bool confirmDeleteSourceCandidate = false,
}) {
  return showCupertinoBottomSheetDialog<ReaderSourceSwitchCandidate>(
    context: context,
    builder: (_) => SourceSwitchCandidateSheet(
      keyword: keyword,
      currentSourceUrl: currentSourceUrl,
      candidates: candidates,
      changeSourceGroup: changeSourceGroup,
      sourceGroups: sourceGroups,
      authorKeyword: authorKeyword,
      checkAuthorEnabled: checkAuthorEnabled,
      loadInfoEnabled: loadInfoEnabled,
      loadWordCountEnabled: loadWordCountEnabled,
      loadTocEnabled: loadTocEnabled,
      changeSourceDelaySeconds: changeSourceDelaySeconds,
      onCheckAuthorChanged: onCheckAuthorChanged,
      onLoadInfoChanged: onLoadInfoChanged,
      onLoadWordCountChanged: onLoadWordCountChanged,
      onLoadTocChanged: onLoadTocChanged,
      onChangeSourceDelayChanged: onChangeSourceDelayChanged,
      onChangeSourceGroupChanged: onChangeSourceGroupChanged,
      onOpenSourceManage: onOpenSourceManage,
      onStartCandidatesSearch: onStartCandidatesSearch,
      onStopCandidatesSearch: onStopCandidatesSearch,
      onRefreshCandidates: onRefreshCandidates,
      onTopSourceCandidate: onTopSourceCandidate,
      onEditSourceCandidate: onEditSourceCandidate,
      onBottomSourceCandidate: onBottomSourceCandidate,
      onDisableSourceCandidate: onDisableSourceCandidate,
      onDeleteSourceCandidate: onDeleteSourceCandidate,
      confirmDeleteSourceCandidate: confirmDeleteSourceCandidate,
    ),
  );
}

class SourceSwitchCandidateSheet extends StatefulWidget {
  final String keyword;
  final String currentSourceUrl;
  final List<ReaderSourceSwitchCandidate> candidates;
  final String changeSourceGroup;
  final List<String> sourceGroups;
  final String authorKeyword;
  final bool checkAuthorEnabled;
  final bool loadInfoEnabled;
  final bool loadWordCountEnabled;
  final bool loadTocEnabled;
  final int changeSourceDelaySeconds;
  final Future<void> Function(bool enabled)? onCheckAuthorChanged;
  final Future<void> Function(bool enabled)? onLoadInfoChanged;
  final Future<void> Function(bool enabled)? onLoadWordCountChanged;
  final Future<void> Function(bool enabled)? onLoadTocChanged;
  final Future<void> Function(int seconds)? onChangeSourceDelayChanged;
  final Future<void> Function(String group)? onChangeSourceGroupChanged;
  final Future<void> Function()? onOpenSourceManage;
  final Future<List<ReaderSourceSwitchCandidate>> Function(
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onStartCandidatesSearch;
  final Future<void> Function()? onStopCandidatesSearch;
  final Future<List<ReaderSourceSwitchCandidate>> Function(
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onRefreshCandidates;
  final Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onTopSourceCandidate;
  final Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onEditSourceCandidate;
  final Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onBottomSourceCandidate;
  final Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onDisableSourceCandidate;
  final Future<List<ReaderSourceSwitchCandidate>> Function(
    ReaderSourceSwitchCandidate candidate,
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onDeleteSourceCandidate;
  final bool confirmDeleteSourceCandidate;

  const SourceSwitchCandidateSheet({
    super.key,
    required this.keyword,
    this.currentSourceUrl = '',
    required this.candidates,
    this.changeSourceGroup = '',
    this.sourceGroups = const <String>[],
    this.authorKeyword = '',
    this.checkAuthorEnabled = false,
    this.loadInfoEnabled = false,
    this.loadWordCountEnabled = false,
    required this.loadTocEnabled,
    this.changeSourceDelaySeconds = 0,
    this.onCheckAuthorChanged,
    this.onLoadInfoChanged,
    this.onLoadWordCountChanged,
    this.onLoadTocChanged,
    this.onChangeSourceDelayChanged,
    this.onChangeSourceGroupChanged,
    this.onOpenSourceManage,
    this.onStartCandidatesSearch,
    this.onStopCandidatesSearch,
    this.onRefreshCandidates,
    this.onTopSourceCandidate,
    this.onEditSourceCandidate,
    this.onBottomSourceCandidate,
    this.onDisableSourceCandidate,
    this.onDeleteSourceCandidate,
    this.confirmDeleteSourceCandidate = false,
  });

  @override
  State<SourceSwitchCandidateSheet> createState() =>
      _SourceSwitchCandidateSheetState();
}

class _SourceSwitchCandidateSheetState
    extends State<SourceSwitchCandidateSheet> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();
  String _query = '';
  bool _filterExpanded = false;
  bool _openingSourceManage = false;
  bool _searchingCandidates = false;
  bool _stoppingCandidates = false;
  bool _refreshingCandidates = false;
  bool _updatingCheckAuthor = false;
  bool _updatingLoadInfo = false;
  bool _updatingLoadWordCount = false;
  bool _updatingLoadToc = false;
  bool _updatingSourceDelay = false;
  bool _updatingSourceGroup = false;
  bool _updatingTopSource = false;
  bool _editingSource = false;
  bool _updatingBottomSource = false;
  bool _disablingSource = false;
  bool _deletingSource = false;
  int _candidateSearchRequestSerial = 0;
  late bool _checkAuthorEnabled;
  late bool _loadInfoEnabled;
  late bool _loadWordCountEnabled;
  late bool _loadTocEnabled;
  late String _changeSourceGroup;
  late int _changeSourceDelaySeconds;
  late List<ReaderSourceSwitchCandidate> _candidates;

  List<ReaderSourceSwitchCandidate> get _filteredCandidates {
    final filtered = ReaderSourceSwitchHelper.filterCandidates(
      candidates: _candidates,
      query: _query,
    );
    return ReaderSourceSwitchHelper.filterCandidatesByAuthor(
      candidates: filtered,
      authorKeyword: widget.authorKeyword,
      checkAuthorEnabled: _checkAuthorEnabled,
    );
  }

  @override
  void initState() {
    super.initState();
    _checkAuthorEnabled = widget.checkAuthorEnabled;
    _loadInfoEnabled = widget.loadInfoEnabled;
    _loadWordCountEnabled = widget.loadWordCountEnabled;
    _loadTocEnabled = widget.loadTocEnabled;
    _changeSourceGroup = _normalizeGroupText(widget.changeSourceGroup);
    _changeSourceDelaySeconds =
        _normalizeDelaySeconds(widget.changeSourceDelaySeconds);
    _candidates = List<ReaderSourceSwitchCandidate>.from(
      widget.candidates,
      growable: false,
    );
    _queryController.addListener(_handleQueryChanged);
  }

  @override
  void didUpdateWidget(covariant SourceSwitchCandidateSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkAuthorEnabled != widget.checkAuthorEnabled) {
      _checkAuthorEnabled = widget.checkAuthorEnabled;
    }
    if (oldWidget.loadInfoEnabled != widget.loadInfoEnabled) {
      _loadInfoEnabled = widget.loadInfoEnabled;
    }
    if (oldWidget.loadWordCountEnabled != widget.loadWordCountEnabled) {
      _loadWordCountEnabled = widget.loadWordCountEnabled;
    }
    if (oldWidget.loadTocEnabled != widget.loadTocEnabled) {
      _loadTocEnabled = widget.loadTocEnabled;
    }
    if (oldWidget.changeSourceGroup != widget.changeSourceGroup) {
      _changeSourceGroup = _normalizeGroupText(widget.changeSourceGroup);
    }
    if (oldWidget.changeSourceDelaySeconds != widget.changeSourceDelaySeconds) {
      _changeSourceDelaySeconds =
          _normalizeDelaySeconds(widget.changeSourceDelaySeconds);
    }
  }

  @override
  void dispose() {
    _queryFocusNode.dispose();
    _queryController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    final value = _queryController.text;
    if (value == _query) return;
    setState(() => _query = value);
  }

  void _openFilter() {
    if (_filterExpanded) {
      _queryFocusNode.requestFocus();
      return;
    }
    setState(() => _filterExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _queryFocusNode.requestFocus();
    });
  }

  void _collapseFilter() {
    _queryFocusNode.unfocus();
    _queryController.clear();
    if (!_filterExpanded) return;
    setState(() => _filterExpanded = false);
  }

  Future<void> _handleOpenSourceManage() async {
    final onOpenSourceManage = widget.onOpenSourceManage;
    if (onOpenSourceManage == null ||
        _openingSourceManage ||
        _refreshingCandidates) {
      return;
    }
    setState(() => _openingSourceManage = true);
    try {
      await onOpenSourceManage();
    } finally {
      if (mounted) {
        setState(() => _openingSourceManage = false);
      }
    }
  }

  Future<void> _handleStartCandidatesSearch() async {
    final onStartCandidatesSearch = widget.onStartCandidatesSearch;
    if (onStartCandidatesSearch == null ||
        _searchingCandidates ||
        _refreshingCandidates ||
        _openingSourceManage) {
      return;
    }
    setState(() {
      _searchingCandidates = true;
      _stoppingCandidates = false;
    });
    final requestSerial = ++_candidateSearchRequestSerial;
    final currentCandidates = List<ReaderSourceSwitchCandidate>.from(
      _candidates,
      growable: false,
    );
    try {
      final searched = await onStartCandidatesSearch(currentCandidates);
      if (!mounted || requestSerial != _candidateSearchRequestSerial) return;
      setState(() {
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          searched,
          growable: false,
        );
      });
    } catch (_) {
      // 与 legado 一致：停止/失败时保持当前列表，不追加扩展提示。
    } finally {
      if (mounted && requestSerial == _candidateSearchRequestSerial) {
        setState(() {
          _searchingCandidates = false;
          _stoppingCandidates = false;
        });
      }
    }
  }

  Future<void> _handleStopCandidatesSearch() async {
    final onStopCandidatesSearch = widget.onStopCandidatesSearch;
    if (onStopCandidatesSearch == null ||
        !_searchingCandidates ||
        _stoppingCandidates) {
      return;
    }
    setState(() => _stoppingCandidates = true);
    try {
      await onStopCandidatesSearch();
    } catch (_) {
      // 与 legado 一致：停止失败不追加提示。
    }
  }

  Future<void> _handleRefreshCandidates() async {
    final onRefreshCandidates = widget.onRefreshCandidates;
    if (onRefreshCandidates == null ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _openingSourceManage) {
      return;
    }
    setState(() => _refreshingCandidates = true);
    final currentCandidates = List<ReaderSourceSwitchCandidate>.from(
      _filteredCandidates,
      growable: false,
    );
    try {
      final refreshed = await onRefreshCandidates(currentCandidates);
      if (!mounted) return;
      setState(() {
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          refreshed,
          growable: false,
        );
      });
    } catch (_) {
      // 与 legado 一致：刷新失败保持当前列表且不弹额外提示。
    } finally {
      if (mounted) {
        setState(() => _refreshingCandidates = false);
      }
    }
  }

  Future<void> _handleTopSourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final onTopSourceCandidate = widget.onTopSourceCandidate;
    if (onTopSourceCandidate == null ||
        _updatingTopSource ||
        _updatingBottomSource ||
        _deletingSource ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _stoppingCandidates) {
      return;
    }
    setState(() => _updatingTopSource = true);
    final currentCandidates = List<ReaderSourceSwitchCandidate>.from(
      _candidates,
      growable: false,
    );
    try {
      final updated = await onTopSourceCandidate(candidate, currentCandidates);
      if (!mounted) return;
      setState(() {
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          updated,
          growable: false,
        );
      });
    } catch (_) {
      // 与 legado 一致：置顶失败保持静默。
    } finally {
      if (mounted) {
        setState(() => _updatingTopSource = false);
      }
    }
  }

  Future<void> _handleBottomSourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final onBottomSourceCandidate = widget.onBottomSourceCandidate;
    if (onBottomSourceCandidate == null ||
        _updatingTopSource ||
        _updatingBottomSource ||
        _disablingSource ||
        _deletingSource ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _stoppingCandidates) {
      return;
    }
    setState(() => _updatingBottomSource = true);
    final currentCandidates = List<ReaderSourceSwitchCandidate>.from(
      _candidates,
      growable: false,
    );
    try {
      final updated =
          await onBottomSourceCandidate(candidate, currentCandidates);
      if (!mounted) return;
      setState(() {
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          updated,
          growable: false,
        );
      });
    } catch (_) {
      // 与 legado 一致：置底失败保持静默。
    } finally {
      if (mounted) {
        setState(() => _updatingBottomSource = false);
      }
    }
  }

  Future<void> _handleEditSourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final onEditSourceCandidate = widget.onEditSourceCandidate;
    if (onEditSourceCandidate == null ||
        _updatingTopSource ||
        _editingSource ||
        _updatingBottomSource ||
        _disablingSource ||
        _deletingSource ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _stoppingCandidates) {
      return;
    }
    setState(() => _editingSource = true);
    final currentCandidates = List<ReaderSourceSwitchCandidate>.from(
      _candidates,
      growable: false,
    );
    try {
      final updated = await onEditSourceCandidate(candidate, currentCandidates);
      if (!mounted) return;
      setState(() {
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          updated,
          growable: false,
        );
      });
    } catch (_) {
      // 与 legado 一致：编辑源返回失败保持当前列表，不追加提示。
    } finally {
      if (mounted) {
        setState(() => _editingSource = false);
      }
    }
  }

  Future<void> _handleDisableSourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final onDisableSourceCandidate = widget.onDisableSourceCandidate;
    if (onDisableSourceCandidate == null ||
        _updatingTopSource ||
        _editingSource ||
        _updatingBottomSource ||
        _disablingSource ||
        _deletingSource ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _stoppingCandidates) {
      return;
    }
    setState(() => _disablingSource = true);
    final currentCandidates = List<ReaderSourceSwitchCandidate>.from(
      _candidates,
      growable: false,
    );
    try {
      final updated =
          await onDisableSourceCandidate(candidate, currentCandidates);
      if (!mounted) return;
      setState(() {
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          updated,
          growable: false,
        );
      });
    } catch (_) {
      // 与 legado 一致：禁用失败保持静默并维持当前候选列表。
    } finally {
      if (mounted) {
        setState(() => _disablingSource = false);
      }
    }
  }

  Future<void> _handleDeleteSourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final onDeleteSourceCandidate = widget.onDeleteSourceCandidate;
    if (onDeleteSourceCandidate == null ||
        _updatingTopSource ||
        _editingSource ||
        _updatingBottomSource ||
        _disablingSource ||
        _deletingSource ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _stoppingCandidates) {
      return;
    }
    setState(() => _deletingSource = true);
    final currentCandidates = List<ReaderSourceSwitchCandidate>.from(
      _candidates,
      growable: false,
    );
    try {
      final updated =
          await onDeleteSourceCandidate(candidate, currentCandidates);
      if (!mounted) return;
      setState(() {
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          updated,
          growable: false,
        );
      });
    } catch (_) {
      // 与 legado 一致：删除失败保持静默并维持当前候选列表。
    } finally {
      if (mounted) {
        setState(() => _deletingSource = false);
      }
    }
  }

  Future<void> _showCandidateActions(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final hasCandidateActions = widget.onTopSourceCandidate != null ||
        widget.onEditSourceCandidate != null ||
        widget.onBottomSourceCandidate != null ||
        widget.onDisableSourceCandidate != null ||
        widget.onDeleteSourceCandidate != null;
    if (!hasCandidateActions ||
        _updatingTopSource ||
        _editingSource ||
        _updatingBottomSource ||
        _disablingSource ||
        _deletingSource ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _stoppingCandidates ||
        _updatingSourceGroup ||
        _updatingCheckAuthor ||
        _updatingLoadInfo ||
        _updatingLoadWordCount ||
        _updatingLoadToc ||
        _updatingSourceDelay) {
      return;
    }
    final action =
        await showCupertinoBottomSheetDialog<_SourceSwitchCandidateAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          if (widget.onTopSourceCandidate != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(
                  sheetContext,
                ).pop(_SourceSwitchCandidateAction.topSource);
              },
              child: const Text('置顶'),
            ),
          if (widget.onBottomSourceCandidate != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(
                  sheetContext,
                ).pop(_SourceSwitchCandidateAction.bottomSource);
              },
              child: const Text('置底'),
            ),
          if (widget.onEditSourceCandidate != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(
                  sheetContext,
                ).pop(_SourceSwitchCandidateAction.editSource);
              },
              child: const Text('编辑源'),
            ),
          if (widget.onDisableSourceCandidate != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(
                  sheetContext,
                ).pop(_SourceSwitchCandidateAction.disableSource);
              },
              isDestructiveAction: true,
              child: const Text('禁用源'),
            ),
          if (widget.onDeleteSourceCandidate != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(
                  sheetContext,
                ).pop(_SourceSwitchCandidateAction.deleteSource);
              },
              isDestructiveAction: true,
              child: const Text('删除源'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (action == _SourceSwitchCandidateAction.topSource) {
      await _handleTopSourceCandidate(candidate);
    } else if (action == _SourceSwitchCandidateAction.editSource) {
      await _handleEditSourceCandidate(candidate);
    } else if (action == _SourceSwitchCandidateAction.bottomSource) {
      await _handleBottomSourceCandidate(candidate);
    } else if (action == _SourceSwitchCandidateAction.disableSource) {
      await _handleDisableSourceCandidate(candidate);
    } else if (action == _SourceSwitchCandidateAction.deleteSource) {
      if (widget.confirmDeleteSourceCandidate) {
        final confirmed = await _confirmDeleteSourceCandidate(candidate);
        if (!confirmed) return;
      }
      await _handleDeleteSourceCandidate(candidate);
    }
  }

  Future<bool> _confirmDeleteSourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n${candidate.source.bookSourceName}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleToggleLoadToc() async {
    final onLoadTocChanged = widget.onLoadTocChanged;
    if (onLoadTocChanged == null || _updatingLoadToc) {
      return;
    }
    final next = !_loadTocEnabled;
    setState(() {
      _loadTocEnabled = next;
      _updatingLoadToc = true;
    });
    try {
      await onLoadTocChanged(next);
    } finally {
      if (mounted) {
        setState(() => _updatingLoadToc = false);
      }
    }
  }

  Future<void> _handleToggleLoadInfo() async {
    final onLoadInfoChanged = widget.onLoadInfoChanged;
    if (onLoadInfoChanged == null || _updatingLoadInfo) {
      return;
    }
    final next = !_loadInfoEnabled;
    setState(() {
      _loadInfoEnabled = next;
      _updatingLoadInfo = true;
    });
    try {
      await onLoadInfoChanged(next);
    } finally {
      if (mounted) {
        setState(() => _updatingLoadInfo = false);
      }
    }
  }

  Future<void> _handleToggleLoadWordCount() async {
    final onLoadWordCountChanged = widget.onLoadWordCountChanged;
    if (onLoadWordCountChanged == null || _updatingLoadWordCount) {
      return;
    }
    final next = !_loadWordCountEnabled;
    setState(() {
      _loadWordCountEnabled = next;
      _updatingLoadWordCount = true;
    });
    try {
      await onLoadWordCountChanged(next);
      if (next &&
          mounted &&
          widget.onRefreshCandidates != null &&
          !_refreshingCandidates &&
          !_searchingCandidates &&
          !_openingSourceManage) {
        await _handleRefreshCandidates();
      }
    } finally {
      if (mounted) {
        setState(() => _updatingLoadWordCount = false);
      }
    }
  }

  Future<void> _handleToggleCheckAuthor() async {
    final onCheckAuthorChanged = widget.onCheckAuthorChanged;
    if (onCheckAuthorChanged == null || _updatingCheckAuthor) {
      return;
    }
    final next = !_checkAuthorEnabled;
    setState(() {
      _checkAuthorEnabled = next;
      _updatingCheckAuthor = true;
    });
    try {
      await onCheckAuthorChanged(next);
    } finally {
      if (mounted) {
        setState(() => _updatingCheckAuthor = false);
      }
    }
  }

  String _normalizeGroupText(String value) {
    return value.trim();
  }

  List<String> get _normalizedSourceGroups {
    final groups = <String>{};
    for (final raw in widget.sourceGroups) {
      final group = _normalizeGroupText(raw);
      if (group.isEmpty) continue;
      groups.add(group);
    }
    return groups.toList(growable: false);
  }

  Future<bool> _confirmSwitchGroupToAll(String group) async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('搜索结果为空'),
        content: Text('$group分组搜索结果为空,是否切换到全部分组'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleChangeSourceGroup(String nextGroup) async {
    final normalized = _normalizeGroupText(nextGroup);
    if (_updatingSourceGroup || normalized == _changeSourceGroup) {
      return;
    }
    final onChangeSourceGroupChanged = widget.onChangeSourceGroupChanged;
    setState(() {
      _changeSourceGroup = normalized;
      _updatingSourceGroup = true;
    });
    try {
      if (onChangeSourceGroupChanged != null) {
        await onChangeSourceGroupChanged(normalized);
      }
      if (widget.onStopCandidatesSearch != null) {
        await widget.onStopCandidatesSearch!();
        if (mounted && _searchingCandidates) {
          setState(() {
            _searchingCandidates = false;
            _stoppingCandidates = false;
          });
        }
      }
      if (widget.onStartCandidatesSearch != null) {
        await _handleStartCandidatesSearch();
      }
      if (mounted &&
          _changeSourceGroup.isNotEmpty &&
          _candidates.isEmpty &&
          onChangeSourceGroupChanged != null &&
          widget.onStartCandidatesSearch != null) {
        final fallbackToAll =
            await _confirmSwitchGroupToAll(_changeSourceGroup);
        if (!mounted || !fallbackToAll) return;
        _changeSourceGroup = '';
        await onChangeSourceGroupChanged('');
        if (widget.onStopCandidatesSearch != null) {
          await widget.onStopCandidatesSearch!();
        }
        await _handleStartCandidatesSearch();
      }
    } finally {
      if (mounted) {
        setState(() => _updatingSourceGroup = false);
      }
    }
  }

  Future<void> _showGroupActions() async {
    if (_updatingSourceGroup ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _updatingCheckAuthor ||
        _updatingLoadInfo ||
        _updatingLoadWordCount ||
        _updatingLoadToc ||
        _updatingSourceDelay) {
      return;
    }
    final groups = _normalizedSourceGroups;
    final selectedGroup = _normalizeGroupText(_changeSourceGroup);
    final selected = await showCupertinoBottomSheetDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('分组'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(''),
            child: Text(selectedGroup.isEmpty ? '✓ 全部书源' : '全部书源'),
          ),
          ...groups.map(
            (group) => CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(group),
              child: Text(
                selectedGroup == group ? '✓ $group' : group,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    await _handleChangeSourceGroup(selected);
  }

  Future<void> _showMoreActions() async {
    if (_openingSourceManage ||
        _refreshingCandidates ||
        _updatingSourceGroup ||
        _updatingCheckAuthor ||
        _updatingLoadInfo ||
        _updatingLoadWordCount ||
        _updatingLoadToc ||
        _updatingSourceDelay) {
      return;
    }
    final action = await showCupertinoBottomSheetDialog<_SourceSwitchMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          if (widget.onCheckAuthorChanged != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop(
                  _SourceSwitchMenuAction.checkAuthor,
                );
              },
              child: Text(_checkAuthorEnabled ? '✓ 校验作者' : '校验作者'),
            ),
          if (widget.onLoadWordCountChanged != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(
                  sheetContext,
                ).pop(_SourceSwitchMenuAction.loadWordCount);
              },
              child: Text(_loadWordCountEnabled ? '✓ 加载字数' : '加载字数'),
            ),
          if (widget.onLoadInfoChanged != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext)
                    .pop(_SourceSwitchMenuAction.loadInfo);
              },
              child: Text(_loadInfoEnabled ? '✓ 加载详情页' : '加载详情页'),
            ),
          if (widget.onLoadTocChanged != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop(_SourceSwitchMenuAction.loadToc);
              },
              child: Text(_loadTocEnabled ? '✓ 加载目录' : '加载目录'),
            ),
          if (widget.onChangeSourceDelayChanged != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop(
                  _SourceSwitchMenuAction.changeSourceDelay,
                );
              },
              child: Text('换源间隔（${_changeSourceDelaySeconds}秒）'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (action == _SourceSwitchMenuAction.checkAuthor) {
      await _handleToggleCheckAuthor();
      return;
    }
    if (action == _SourceSwitchMenuAction.loadWordCount) {
      await _handleToggleLoadWordCount();
      return;
    }
    if (action == _SourceSwitchMenuAction.loadInfo) {
      await _handleToggleLoadInfo();
      return;
    }
    if (action == _SourceSwitchMenuAction.loadToc) {
      await _handleToggleLoadToc();
      return;
    }
    if (action == _SourceSwitchMenuAction.changeSourceDelay) {
      await _handleChangeSourceDelay();
    }
  }

  int _normalizeDelaySeconds(int value) {
    return value.clamp(0, 9999).toInt();
  }

  Future<void> _handleChangeSourceDelay() async {
    final onChangeSourceDelayChanged = widget.onChangeSourceDelayChanged;
    if (onChangeSourceDelayChanged == null || _updatingSourceDelay) {
      return;
    }
    final picked = await _showChangeSourceDelayPicker();
    if (!mounted || picked == null) return;
    final next = _normalizeDelaySeconds(picked);
    if (next == _changeSourceDelaySeconds) return;
    setState(() {
      _changeSourceDelaySeconds = next;
      _updatingSourceDelay = true;
    });
    try {
      await onChangeSourceDelayChanged(next);
    } finally {
      if (mounted) {
        setState(() => _updatingSourceDelay = false);
      }
    }
  }

  Future<int?> _showChangeSourceDelayPicker() async {
    final initialValue = _normalizeDelaySeconds(_changeSourceDelaySeconds);
    final pickerController = FixedExtentScrollController(
      initialItem: initialValue,
    );
    var selectedValue = initialValue;
    final result = await showCupertinoBottomSheetDialog<int>(
      context: context,
      builder: (sheetContext) {
        final theme = CupertinoTheme.of(sheetContext);
        final backgroundColor = theme.scaffoldBackgroundColor;
        return Container(
          height: 320,
          color: backgroundColor,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            '换源间隔',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(selectedValue),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: CupertinoPicker.builder(
                    itemExtent: 36,
                    scrollController: pickerController,
                    onSelectedItemChanged: (index) {
                      selectedValue = index;
                    },
                    childCount: 10000,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Text('$index 秒'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    pickerController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupertinoTheme.of(context);
    final compactTapSquare =
        AppUiTokens.resolve(context).sizes.compactTapSquare;
    final size = MediaQuery.sizeOf(context);
    final filtered = _filteredCandidates;
    final showCheckAuthorAction = widget.onCheckAuthorChanged != null;
    final showLoadInfoAction = widget.onLoadInfoChanged != null;
    final showLoadWordCountAction = widget.onLoadWordCountChanged != null;
    final showGroupAction = widget.onChangeSourceGroupChanged != null;
    final groupButtonLabel =
        _changeSourceGroup.isEmpty ? '分组' : '分组(${_changeSourceGroup})';
    final showMoreButton = widget.onLoadTocChanged != null ||
        widget.onChangeSourceDelayChanged != null ||
        showCheckAuthorAction ||
        showLoadInfoAction ||
        showLoadWordCountAction;
    final showHeaderTitle = !_filterExpanded;

    return SafeArea(
      top: false,
      child: Container(
        height: size.height * 0.8,
        decoration: BoxDecoration(
          color: colors.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDesignTokens.radiusSheet)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.separator.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: showHeaderTitle
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '换源（${widget.keyword}）',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '候选 ${_candidates.length} 条',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey.resolveFrom(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: compactTapSquare,
                        onPressed:
                            _filterExpanded ? _collapseFilter : _openFilter,
                        child: Text(_filterExpanded ? '收起' : '筛选'),
                      ),
                      const SizedBox(width: 12),
                      if (widget.onStartCandidatesSearch != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: compactTapSquare,
                          onPressed: (_openingSourceManage ||
                                  _refreshingCandidates ||
                                  (_searchingCandidates &&
                                      widget.onStopCandidatesSearch == null) ||
                                  _stoppingCandidates)
                              ? null
                              : (_searchingCandidates
                                  ? _handleStopCandidatesSearch
                                  : _handleStartCandidatesSearch),
                          child: Text(
                            _searchingCandidates
                                ? (_stoppingCandidates ? '停止中' : '停止')
                                : '刷新',
                          ),
                        ),
                      if (widget.onStartCandidatesSearch != null)
                        const SizedBox(width: 12),
                      if (widget.onRefreshCandidates != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: compactTapSquare,
                          onPressed: (_refreshingCandidates ||
                                  _searchingCandidates ||
                                  _openingSourceManage)
                              ? null
                              : _handleRefreshCandidates,
                          child: Text(
                            _refreshingCandidates ? '刷新中' : '刷新列表',
                          ),
                        ),
                      if (widget.onRefreshCandidates != null)
                        const SizedBox(width: 12),
                      if (widget.onOpenSourceManage != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: compactTapSquare,
                          onPressed:
                              (_openingSourceManage || _refreshingCandidates)
                                  ? null
                                  : _handleOpenSourceManage,
                          child: const Text('书源管理'),
                        ),
                      const SizedBox(width: 12),
                      if (showGroupAction)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: compactTapSquare,
                          onPressed: (_openingSourceManage ||
                                  _refreshingCandidates ||
                                  _updatingSourceGroup ||
                                  _updatingCheckAuthor ||
                                  _updatingLoadInfo ||
                                  _updatingLoadWordCount ||
                                  _updatingLoadToc ||
                                  _updatingSourceDelay)
                              ? null
                              : _showGroupActions,
                          child: Text(groupButtonLabel),
                        ),
                      if (showGroupAction) const SizedBox(width: 12),
                      if (showMoreButton)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: compactTapSquare,
                          onPressed: (_openingSourceManage ||
                                  _refreshingCandidates ||
                                  _updatingSourceGroup ||
                                  _updatingCheckAuthor ||
                                  _updatingLoadInfo ||
                                  _updatingLoadWordCount ||
                                  _updatingLoadToc ||
                                  _updatingSourceDelay)
                              ? null
                              : _showMoreActions,
                          child: const Text('更多'),
                        ),
                      if (showMoreButton) const SizedBox(width: 12),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: compactTapSquare,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_filterExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: AppManageSearchField(
                  controller: _queryController,
                  focusNode: _queryFocusNode,
                  placeholder: '筛选',
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? AppEmptyState(
                      illustration: const AppEmptyPlanetIllustration(size: 82),
                      title: _query.trim().isEmpty ? '暂无候选书源' : '无匹配候选',
                      message:
                          _query.trim().isEmpty ? '可尝试刷新列表或更换分组' : '请尝试更换筛选关键字',
                    )
                  : ListView.separated(
                      controller: ModalScrollController.of(context),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 0.5,
                        color: CupertinoColors.systemGrey4.resolveFrom(context),
                      ),
                      itemBuilder: (itemContext, index) {
                        final candidate = filtered[index];
                        final isCurrentSource = widget.currentSourceUrl.isNotEmpty &&
                            candidate.source.bookSourceUrl == widget.currentSourceUrl;
                        final sourceName = candidate.source.bookSourceName;
                        final author = candidate.book.author.trim().isEmpty
                            ? '未知作者'
                            : candidate.book.author.trim();
                        final latestChapter = candidate.book.lastChapter.trim();
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: (widget.onTopSourceCandidate == null &&
                                  widget.onEditSourceCandidate == null &&
                                  widget.onBottomSourceCandidate == null &&
                                  widget.onDisableSourceCandidate == null &&
                                  widget.onDeleteSourceCandidate == null)
                              ? null
                              : () {
                                  _showCandidateActions(candidate);
                                },
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            minimumSize: compactTapSquare,
                            onPressed: () =>
                                Navigator.of(itemContext).pop(candidate),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sourceName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.label.resolveFrom(context)
                                          .resolveFrom(itemContext),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    author,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.systemGrey.resolveFrom(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (latestChapter.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      latestChapter,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: CupertinoColors.systemGrey2.resolveFrom(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (_loadWordCountEnabled &&
                                      candidate.chapterWordCountText
                                          .trim()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      candidate.chapterWordCountText.trim(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: CupertinoColors.systemGrey2.resolveFrom(context),
                                      ),
                                    ),
                                  ],
                                  if (candidate.respondTimeMs >= 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '响应时间：${candidate.respondTimeMs} ms',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: CupertinoColors.systemGrey2.resolveFrom(context),
                                      ),
                                    ),
                                  ],
                                ],
                                  ),
                                ),
                                if (isCurrentSource)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      CupertinoIcons.checkmark_alt,
                                      size: 18,
                                      color: CupertinoColors.activeBlue.resolveFrom(context)
                                          .resolveFrom(itemContext),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SourceSwitchMenuAction {
  checkAuthor,
  loadWordCount,
  loadInfo,
  loadToc,
  changeSourceDelay,
}

enum _SourceSwitchCandidateAction {
  topSource,
  editSource,
  bottomSource,
  disableSource,
  deleteSource,
}
