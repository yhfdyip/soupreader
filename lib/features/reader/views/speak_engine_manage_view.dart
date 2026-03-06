import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../models/http_tts_rule.dart';
import '../services/http_tts_rule_store.dart';
import 'http_tts_rule_edit_view.dart';

part 'speak_engine_manage_actions_menu.dart';
part 'speak_engine_manage_actions_import.dart';
part 'speak_engine_manage_actions_import_history.dart';
part 'speak_engine_manage_ui.dart';

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

  void _setRulesLoaded(List<HttpTtsRule> rules) {
    _updateState(() {
      _rules = rules;
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
}

enum _SpeakEngineMenuAction {
  importDefaultRules,
  importLocal,
  importOnline,
  export,
}
