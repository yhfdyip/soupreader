import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openSysTtsConfig() async {
    const url = 'App-prefs:root=ACCESSIBILITY';
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: const Text('无法跳转到系统设置，请手动前往「设置 > 辅助功能 > 朗读内容」'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
            ),
          ],
        ),
      );
    }
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
              AppListTile(
                leadingIcon: CupertinoIcons.settings,
                title: const Text('系统 TTS 设置'),
                additionalInfo: const Text('跳转到系统朗读内容设置'),
                onTap: _openSysTtsConfig,
              ),
            ],
          ),
          if (!kIsWeb && !_excludeTts) ...
            [
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
                  _buildBooleanTile(
                    title: '来电时暂停朗读',
                    additionalInfo: '接到电话时自动暂停朗读',
                    value: _appSettings.pauseReadAloudWhilePhoneCalls,
                    save: _settingsService.savePauseReadAloudWhilePhoneCalls,
                  ),
                  _buildBooleanTile(
                    title: '朗读时保持屏幕常亮',
                    additionalInfo: '防止朗读时屏幕熄灭',
                    value: _appSettings.readAloudWakeLock,
                    save: _settingsService.saveReadAloudWakeLock,
                  ),
                ],
              ),
              AppListSection(
                header: const Text('朗读方式'),
                children: [
                  _buildBooleanTile(
                    title: '按页朗读',
                    additionalInfo: '以页为单位朗读，翻页后继续',
                    value: _appSettings.readAloudByPage,
                    save: _settingsService.saveReadAloudByPage,
                  ),
                  _buildBooleanTile(
                    title: '流式朗读',
                    additionalInfo: '边加载边朗读，减少等待',
                    value: _appSettings.streamReadAloudAudio,
                    save: _settingsService.saveStreamReadAloudAudio,
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
