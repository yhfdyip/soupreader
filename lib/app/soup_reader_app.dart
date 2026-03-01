import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'main_screen.dart';
import 'theme/cupertino_theme.dart';
import '../core/models/app_settings.dart';
import '../core/services/settings_service.dart';

/// SoupReader 阅读应用（bootstrap 完成后进入此 App）。
class SoupReaderApp extends StatefulWidget {
  const SoupReaderApp({super.key});

  @override
  State<SoupReaderApp> createState() => _SoupReaderAppState();
}

class _SoupReaderAppState extends State<SoupReaderApp>
    with WidgetsBindingObserver {
  final SettingsService _settingsService = SettingsService();
  late Brightness _platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    _applySystemUiOverlayStyle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsService.appSettingsListenable.removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
    _applySystemUiOverlayStyle();
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {});
    _applySystemUiOverlayStyle();
  }

  Brightness get _effectiveBrightness {
    final settings = _settingsService.appSettings;
    switch (settings.appearanceMode) {
      case AppAppearanceMode.followSystem:
        return _platformBrightness;
      case AppAppearanceMode.light:
        return Brightness.light;
      case AppAppearanceMode.dark:
        return Brightness.dark;
      case AppAppearanceMode.eInk:
        return Brightness.light;
    }
  }

  void _applySystemUiOverlayStyle() {
    final brightness = _effectiveBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _effectiveBrightness;
    final cupertinoTheme = AppCupertinoTheme.build(brightness);

    return CupertinoApp(
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      theme: cupertinoTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: MainScreen(
        brightness: brightness,
        appSettings: _settingsService.appSettings,
      ),
    );
  }
}
