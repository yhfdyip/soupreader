import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/config/migration_exclusions.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/views/speak_engine_manage_view.dart';

/// 朗读设置页。
class ReadAloudSettingsView extends StatefulWidget {
  const ReadAloudSettingsView({super.key});

  @override
  State<ReadAloudSettingsView> createState() => _ReadAloudSettingsViewState();
}

class _ReadAloudSettingsViewState extends State<ReadAloudSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late AppSettings _appSettings;

  bool get _excludeTts => MigrationExclusions.excludeTts;

  @override
  void initState() {
    super.initState();
    _appSettings = _settingsService.appSettingsListenable.value;
    _settingsService.appSettingsListenable.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _appSettings = _settingsService.appSettingsListenable.value;
    });
  }

  Future<void> _save(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    setState(() {
      _appSettings = _settingsService.appSettingsListenable.value;
    });
  }

  Widget _buildBooleanTile({
    required String title,
    required String additionalInfo,
    required bool value,
    required Future<void> Function(bool) save,
  }) {
    return AppListTile(
      title: Text(title),
      additionalInfo: Text(additionalInfo),
      showChevron: false,
      trailing: CupertinoSwitch(
        value: value,
        onChanged: (v) => _save(() => save(v)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '朗读',
      child: ListView(
        children: [
          AppListSection(
            header: const Text('引擎'),
            children: [
              AppListTile(
                leadingIcon: CupertinoIcons.speaker_2,
                title: const Text('朗读引擎'),
                additionalInfo: const Text('系统/HTTP 引擎'),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const SpeakEngineManageView(),
                  ),
                ),
              ),
            ],
          ),
          if (!kIsWeb && !_excludeTts)
            AppListSection(
              header: const Text('控制'),
              children: [
                _buildBooleanTile(
                  title: '全程响应耳机按键',
                  additionalInfo: '即使退出软件也响应耳机按键',
                  value: _appSettings.mediaButtonOnExit,
                  save: _settingsService.saveMediaButtonOnExit,
                ),
                _buildBooleanTile(
                  title: '耳机按键启动朗读',
                  additionalInfo: '通过耳机按键来启动朗读',
                  value: _appSettings.readAloudByMediaButton,
                  save: _settingsService.saveReadAloudByMediaButton,
                ),
                _buildBooleanTile(
                  title: '忽略音频焦点',
                  additionalInfo: '允许与其他应用同时播放音频',
                  value: _appSettings.ignoreAudioFocus,
                  save: _settingsService.saveIgnoreAudioFocus,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
