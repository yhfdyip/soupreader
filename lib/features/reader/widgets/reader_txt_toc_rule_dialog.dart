import 'package:flutter/cupertino.dart';

import '../../import/txt_parser.dart';

class ReaderTxtTocRuleDialog extends StatefulWidget {
  final String currentRegex;
  final List<TxtTocRuleOption> options;
  final Color? accentColor;

  const ReaderTxtTocRuleDialog({
    super.key,
    required this.currentRegex,
    this.options = TxtParser.defaultTocRuleOptions,
    this.accentColor,
  });

  static Future<String?> show({
    required BuildContext context,
    required String currentRegex,
    Color? accentColor,
    List<TxtTocRuleOption> options = TxtParser.defaultTocRuleOptions,
  }) {
    return showCupertinoDialog<String?>(
      context: context,
      builder: (_) => ReaderTxtTocRuleDialog(
        currentRegex: currentRegex,
        options: options,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<ReaderTxtTocRuleDialog> createState() => _ReaderTxtTocRuleDialogState();
}

class _ReaderTxtTocRuleDialogState extends State<ReaderTxtTocRuleDialog> {
  late String _selectedRule;

  @override
  void initState() {
    super.initState();
    _selectedRule = widget.currentRegex.trim();
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.accentColor ?? CupertinoColors.activeBlue.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final choices = _buildChoices();
    final maxRows = choices.length.clamp(3, 6);
    final dialogHeight = (maxRows * 44.0).toDouble();

    return CupertinoAlertDialog(
      title: const Text('TXT 目录规则'),
      content: SizedBox(
        width: double.maxFinite,
        child: SizedBox(
          height: dialogHeight,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var index = 0; index < choices.length; index += 1) ...[
                  CupertinoButton(
                    key: ValueKey<String>('reader_txt_toc_rule_option_$index'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 10,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRule = choices[index].rule;
                      });
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            choices[index].label,
                            style: TextStyle(
                              color: _selectedRule == choices[index].rule
                                  ? accent
                                  : labelColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_selectedRule == choices[index].rule)
                          Icon(
                            CupertinoIcons.check_mark,
                            key: ValueKey<String>(
                              'reader_txt_toc_rule_selected_$index',
                            ),
                            size: 16,
                            color: accent,
                          ),
                      ],
                    ),
                    minimumSize: Size(0, 0),
                  ),
                  if (index != choices.length - 1)
                    Container(
                      height: 0.5,
                      color: separatorColor,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          key: const Key('reader_txt_toc_rule_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          key: const Key('reader_txt_toc_rule_confirm'),
          onPressed: () => Navigator.of(context).pop(_selectedRule),
          child: const Text('确定'),
        ),
      ],
    );
  }

  List<_ReaderTxtTocRuleChoice> _buildChoices() {
    final choices = <_ReaderTxtTocRuleChoice>[
      const _ReaderTxtTocRuleChoice(
        label: '自动识别（默认）',
        rule: '',
      ),
      ...widget.options.map(
        (option) => _ReaderTxtTocRuleChoice(
          label: option.name,
          rule: option.rule,
        ),
      ),
    ];
    if (_selectedRule.isNotEmpty &&
        !choices.any((choice) => choice.rule == _selectedRule)) {
      choices.insert(
        1,
        _ReaderTxtTocRuleChoice(
          label: '当前规则（自定义）',
          rule: _selectedRule,
        ),
      );
    }
    return choices;
  }
}

class _ReaderTxtTocRuleChoice {
  final String label;
  final String rule;

  const _ReaderTxtTocRuleChoice({
    required this.label,
    required this.rule,
  });
}
