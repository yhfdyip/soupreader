import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart' as html_parser;

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
  late final DictRuleStore _dictRuleStore;

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
    unawaited(_loadRules());
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
      return CupertinoSlidingSegmentedControl<int>(
        groupValue: _selectedIndex,
        children: {
          for (var i = 0; i < _rules.length; i++)
            i: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(
                _rules[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          unawaited(_selectRule(value));
        },
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
            minSize: 32,
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
          );
        },
      ),
    );
  }

  Widget _buildResultPanel() {
    if (_loadingRules || _loadingResult) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_displayText.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SelectableText(
        _displayText,
        style: const TextStyle(fontSize: 14, height: 1.45),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.78;
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: maxHeight,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minSize: 30,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '字典',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.selectedText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              if (_rules.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildRuleTabs(),
                ),
              const SizedBox(height: 6),
              Expanded(child: _buildResultPanel()),
            ],
          ),
        ),
      ),
    );
  }
}
