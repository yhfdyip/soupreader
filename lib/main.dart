import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/boot_failure_view.dart';
import 'app/main_screen.dart';
import 'app/theme/cupertino_theme.dart';
import 'core/models/app_settings.dart';
import 'core/services/exception_log_service.dart';
import 'core/services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[flutter-error] ${details.exceptionAsString()}');
    ExceptionLogService().record(
      node: 'global.flutter_error',
      message: details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
      context: <String, dynamic>{
        if (details.library != null) 'library': details.library!,
      },
    );
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[platform-error] $error');
    ExceptionLogService().record(
      node: 'global.platform_error',
      message: 'PlatformDispatcher.onError',
      error: error,
      stackTrace: stack,
    );
    debugPrintStack(stackTrace: stack);
    return true;
  };

  runZonedGuarded(() async {
    final bootFailure = await bootstrapApp();

    debugPrint('[boot] runApp start');
    runApp(SoupReaderApp(initialBootFailure: bootFailure));
    debugPrint('[boot] runApp done');
  }, (Object error, StackTrace stack) {
    debugPrint('[zone-error] $error');
    ExceptionLogService().record(
      node: 'global.zone_error',
      message: 'runZonedGuarded 捕获未处理异常',
      error: error,
      stackTrace: stack,
    );
    debugPrintStack(stackTrace: stack);
  });
}

// ── SoupReaderApp（内联，与 main 分支对齐） ──

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
  bool _bootRetrying = false;
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
    setState(() {});
    _applySystemUiOverlayStyle();
  }

  Future<void> _retryBoot() async {
    if (_bootRetrying) return;
    setState(() => _bootRetrying = true);
    final failure = await bootstrapApp();
    if (!mounted) return;
    final retrySuccess = failure == null;
    if (retrySuccess && !_settingsReady) {
      _settingsReady = true;
      _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    }
    setState(() {
      _bootFailure = failure;
      _bootRetrying = false;
    });
    _applySystemUiOverlayStyle();
  }

  Brightness get _effectiveBrightness {
    if (!_settingsReady) {
      return _platformBrightness;
    }
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
      home: _bootFailure == null
          ? MainScreen(
              brightness: brightness,
              appSettings: _settingsReady
                  ? _settingsService.appSettings
                  : const AppSettings(),
            )
          : BootFailureView(
              failure: _bootFailure!,
              retrying: _bootRetrying,
              onRetry: _retryBoot,
              bootLog: '',
            ),
    );
  }
}
