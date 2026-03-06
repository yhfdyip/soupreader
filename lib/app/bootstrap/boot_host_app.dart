import 'dart:async';
import '../widgets/cupertino_bottom_dialog.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../app/theme/cupertino_theme.dart';
import '../../core/bootstrap/boot_log.dart';
import '../../core/models/app_settings.dart';
import '../../core/services/exception_log_service.dart';
import '../../core/services/settings_service.dart';
import '../main_screen.dart';
import 'app_bootstrap.dart';
import 'booting_progress_view.dart';
import 'boot_failure_view.dart';

class BootHostApp extends StatefulWidget {
  const BootHostApp({super.key});

  @override
  State<BootHostApp> createState() => _BootHostAppState();
}

class _BootHostAppState extends State<BootHostApp> with WidgetsBindingObserver {
  static const Duration _kTickerInterval = Duration(seconds: 1);
  static const int _kMaxLogLines = 160;
  static const int _kVisibleLogLines = 18;

  final List<String> _logLines = <String>[];
  Timer? _ticker;
  int _startedAtMs = 0;
  String _step = 'boot.start';

  BootFailure? _failure;
  bool _booting = true;

  // ── bootstrap 成功后使用 ──
  final SettingsService _settingsService = SettingsService();
  late Brightness _platformBrightness;
  bool _settingsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;

    BootLog.bind(_appendLog);
    _appendLog('[boot-host] mounted');

    _ticker = Timer.periodic(_kTickerInterval, (_) {
      if (!mounted) return;
      if (!_booting) return;
      setState(() {});
    });

    // Ensure the first frame is rendered before starting heavy init work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runBootstrap());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    BootLog.unbind();
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

  void _appendLog(String message) {
    _logLines.add(message);
    if (_logLines.length > _kMaxLogLines) {
      _logLines.removeRange(0, _logLines.length - _kMaxLogLines);
    }
    if (!mounted) return;
    setState(() {});
  }

  void _setStep(String step) {
    _step = step;
    _appendLog('[boot] step=$step');
  }

  Future<void> _runBootstrap() async {
    setState(() {
      _failure = null;
      _booting = true;
      _step = 'boot.start';
      _startedAtMs = DateTime.now().millisecondsSinceEpoch;
      _logLines.clear();
    });

    BootLog.bind(_appendLog);
    _appendLog('[boot-host] bootstrap begin');

    BootFailure? failure;
    try {
      failure = await bootstrapApp(onStepChanged: _setStep);
    } catch (e, st) {
      _appendLog('[boot-host] unexpected error: $e');
      ExceptionLogService().record(
        node: 'bootstrap.unexpected',
        message: '启动流程发生未捕获异常',
        error: e,
        stackTrace: st,
      );
      failure = BootFailure(stepName: 'unknown', error: e, stack: st);
    }

    if (!mounted) return;

    if (failure == null) {
      _appendLog('[boot-host] bootstrap ok');
      BootLog.unbind();
      // Bootstrap 成功，开始监听设置变化。
      _settingsReady = true;
      _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
      _applySystemUiOverlayStyle();
    } else {
      _appendLog('[boot-host] bootstrap failed: ${failure.stepName}');
    }

    setState(() {
      _failure = failure;
      _booting = false;
    });
  }

  String _bootLogPayload() => _logLines.join('\n').trim();

  String _latestLogLine() {
    if (_logLines.isEmpty) return '';
    return _logLines.last.trim();
  }

  String _bootLogTailPayload() {
    if (_logLines.isEmpty) return '';
    final start =
        (_logLines.length - _kVisibleLogLines).clamp(0, _logLines.length);
    // Show newest first so the "current stuck line" is visible without scrolling.
    return _logLines.sublist(start).reversed.join('\n').trim();
  }

  Future<void> _copyBootLog(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _bootLogPayload()));
    if (!context.mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('已复制'),
        content: const Text('启动日志已复制到剪贴板。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  CupertinoApp _buildBootingApp() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final theme = AppCupertinoTheme.build(brightness);
    final elapsedSeconds =
        (DateTime.now().millisecondsSinceEpoch - _startedAtMs) / 1000.0;
    final hasLogs = _logLines.isNotEmpty;

    return CupertinoApp(
      key: const ValueKey('boot'),
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => child ?? const SizedBox.shrink(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: BootingProgressView(
        step: _step,
        elapsedSeconds: elapsedSeconds,
        latestLogLine: _latestLogLine(),
        bootLogTail: _bootLogTailPayload(),
        hasLogs: hasLogs,
        onCopyLog: _copyBootLog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (_booting) {
      return _buildBootingApp();
    }

    final brightness = _effectiveBrightness;
    final theme = AppCupertinoTheme.build(brightness);

    final Widget home;
    if (failure != null) {
      home = BootFailureView(
        failure: failure,
        retrying: false,
        onRetry: () => unawaited(_runBootstrap()),
        bootLog: _bootLogPayload(),
      );
    } else {
      home = MainScreen(
        brightness: brightness,
        appSettings:
            _settingsReady ? _settingsService.appSettings : const AppSettings(),
      );
    }

    return CupertinoApp(
      key: const ValueKey('main'),
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => child ?? const SizedBox.shrink(),
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
