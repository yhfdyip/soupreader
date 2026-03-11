import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../models/dict_rule.dart';
import '../services/dict_rule_store.dart';

class ReaderDictLookupSheet extends StatefulWidget {
  final String selectedText;
  final DictRuleStore? dictRuleStore;

  const ReaderDictLookupSheet({
    super.key,
    required this.selectedText,
    this.dictRuleStore,
  });

  @override
  State<ReaderDictLookupSheet> createState() => _ReaderDictLookupSheetState();
}

class _ReaderDictLookupSheetState extends State<ReaderDictLookupSheet> {
  static const double _kWidthFactor = 0.92;
  static const double _kHeightFactor = 0.78;
  static const double _kMaxWidth = 760;
  static const double _kMaxHeight = 720;

  late final DictRuleStore _dictRuleStore;
  late final FocusNode _resultFocusNode;

  List<DictRule> _rules = const <DictRule>[];
  int _selectedIndex = 0;
  bool _loadingRules = true;
  bool _loadingResult = false;
  String _displayText = '';
  int _activeRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _dictRuleStore = widget.dictRuleStore ?? DictRuleStore();
    _resultFocusNode = FocusNode();
    unawaited(_loadRules());
  }

  @override
  void dispose() {
    _resultFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    final rules = await _dictRuleStore.loadEnabledRules();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _selectedIndex = 0;
      _loadingRules = false;
      _displayText = '';
    });
    if (rules.isEmpty) {
      return;
    }
    await _selectRule(0);
  }

  Future<void> _selectRule(int index) async {
    if (index < 0 || index >= _rules.length) return;
    final token = ++_activeRequestToken;
    setState(() {
      _selectedIndex = index;
      _loadingResult = true;
      _displayText = '';
    });
    try {
      final raw = await _dictRuleStore.search(
        rule: _rules[index],
        word: widget.selectedText,
      );
      if (!mounted || token != _activeRequestToken) return;
      setState(() {
        _loadingResult = false;
        _displayText = _normalizeDisplayText(raw);
      });
    } catch (error) {
      if (!mounted || token != _activeRequestToken) return;
      final message = _errorMessage(error);
      setState(() {
        _loadingResult = false;
        _displayText = message;
      });
    }
  }

  String _errorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'ERROR';
    if (raw.startsWith('Exception:')) {
      final stripped = raw.substring('Exception:'.length).trim();
      return stripped.isEmpty ? 'ERROR' : stripped;
    }
    return raw;
  }

  String _normalizeDisplayText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (!RegExp(r'<[^>]+>').hasMatch(trimmed)) {
      return trimmed;
    }
    final document = html_parser.parse(trimmed);
    final text = (document.body?.text ?? document.documentElement?.text ?? '')
        .replaceAll('\r\n', '\n')
        .trim();
    return text.isEmpty ? trimmed : text;
  }

  Widget _buildRuleTabs() {
    if (_rules.isEmpty) return const SizedBox.shrink();
    if (_rules.length <= 4) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedIndex,
          padding: const EdgeInsets.all(3),
          children: {
            for (var i = 0; i < _rules.length; i++)
              i: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(
                  _rules[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          },
          onValueChanged: (value) {
            if (value == null) return;
            unawaited(_selectRule(value));
          },
        ),
      );
    }
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _rules.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _selectedIndex;
          return CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: selected
                ? CupertinoTheme.of(context).primaryColor
                : CupertinoColors.systemGrey5.resolveFrom(context),
            onPressed: () => unawaited(_selectRule(index)),
            child: Text(
              _rules[index].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: selected
                    ? CupertinoColors.white
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
            minimumSize: Size(32, 32),
          );
        },
      ),
    );
  }

  Widget _buildResultPanel(AppUiTokens ui) {
    if (_loadingRules || _loadingResult) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_displayText.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SelectableRegion(
        focusNode: _resultFocusNode,
        selectionControls: cupertinoTextSelectionControls,
        child: Text(
          _displayText,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: ui.colors.label,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => Navigator.of(context).pop(),
            minimumSize: const Size(30, 30),
            child: const Text('关闭'),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '字典',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.selectedText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildDivider(AppUiTokens ui) {
    return Container(
      height: ui.sizes.dividerThickness,
      color: ui.colors.separator.withValues(alpha: 0.78),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width * _kWidthFactor, _kMaxWidth);
    final height = math.min(size.height * _kHeightFactor, _kMaxHeight);

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: AppSheetPanel(
          contentPadding: EdgeInsets.zero,
          radius: ui.radii.sheet,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(context),
                _buildDivider(ui),
                if (_rules.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: _buildRuleTabs(),
                  ),
                const SizedBox(height: 6),
                Expanded(child: _buildResultPanel(ui)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
