import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/boot_failure_view.dart';
import 'main_screen.dart';
import 'theme/cupertino_theme.dart';
import '../core/models/app_settings.dart';
import '../core/services/settings_service.dart';

/// SoupReader 阅读应用。
///
/// 当 [initialBootFailure] 不为 null 时展示启动失败视图，
/// 用户可点击重试；重试成功后自动进入主界面。
class SoupReaderApp extends StatefulWidget {
  final BootFailure? initialBootFailure;

  const SoupReaderApp({super.key, this.initialBootFailure});

  @override
  State<SoupReaderApp> createState() => _SoupReaderAppState();
}

class _SoupReaderAppState extends State<SoupReaderApp>
    with WidgetsBindingObserver {
  final SettingsService _settingsService = SettingsService();
  late Brightness _platformBrightness;

  BootFailure? _bootFailure;
  bool _retrying = false;
  bool _settingsReady = false;

  @override
  void initState() {
    super.initState();
    _bootFailure = widget.initialBootFailure;
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _settingsReady = _bootFailure == null;
    if (_settingsReady) {
      _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    }
    _applySystemUiOverlayStyle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_settingsReady) {
      _settingsService.appSettingsListenable
          .removeListener(_onAppSettingsChanged);
    }
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
    if (!_settingsReady) return _platformBrightness;
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

  /// 重试 bootstrap 流程。
  Future<void> _retryBootstrap() async {
    if (_retrying) return;
    setState(() => _retrying = true);

    final failure = await bootstrapApp();
    if (!mounted) return;

    if (failure == null && !_settingsReady) {
      _settingsReady = true;
      _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    }
    setState(() {
      _bootFailure = failure;
      _retrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _effectiveBrightness;
    final cupertinoTheme = AppCupertinoTheme.build(brightness);

    final Widget home;
    final failure = _bootFailure;
    if (failure != null) {
      home = BootFailureView(
        failure: failure,
        retrying: _retrying,
        onRetry: () => unawaited(_retryBootstrap()),
        bootLog: '',
      );
    } else {
      home = MainScreen(
        brightness: brightness,
        appSettings:
            _settingsReady ? _settingsService.appSettings : const AppSettings(),
      );
    }

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
      home: home,
    );
  }
}
