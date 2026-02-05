import 'package:flutter/cupertino.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';

class AppearanceSettingsView extends StatefulWidget {
  const AppearanceSettingsView({super.key});

  @override
  State<AppearanceSettingsView> createState() => _AppearanceSettingsViewState();
}

class _AppearanceSettingsViewState extends State<AppearanceSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.appSettings;
    _settingsService.appSettingsListenable.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _settings = _settingsService.appSettings);
  }

  @override
  Widget build(BuildContext context) {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final followSystem = _settings.appearanceMode == AppAppearanceMode.followSystem;
    final effectiveIsDark = followSystem
        ? systemBrightness == Brightness.dark
        : _settings.appearanceMode == AppAppearanceMode.dark;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('外观与通用'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('外观'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('跟随系统外观'),
                  trailing: CupertinoSwitch(
                    value: followSystem,
                    onChanged: (value) async {
                      if (value) {
                        await _settingsService.saveAppSettings(
                          _settings.copyWith(
                            appearanceMode: AppAppearanceMode.followSystem,
                          ),
                        );
                        return;
                      }

                      await _settingsService.saveAppSettings(
                        _settings.copyWith(
                          appearanceMode: systemBrightness == Brightness.dark
                              ? AppAppearanceMode.dark
                              : AppAppearanceMode.light,
                        ),
                      );
                    },
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('深色模式'),
                  trailing: CupertinoSwitch(
                    value: effectiveIsDark,
                    onChanged: followSystem
                        ? null
                        : (value) async {
                            await _settingsService.saveAppSettings(
                              _settings.copyWith(
                                appearanceMode: value
                                    ? AppAppearanceMode.dark
                                    : AppAppearanceMode.light,
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('说明'),
              children: const [
                CupertinoListTile(
                  title: Text('本页只影响应用整体外观，不影响阅读主题。'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

