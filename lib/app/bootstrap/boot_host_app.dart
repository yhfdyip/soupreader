import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../core/bootstrap/boot_log.dart';
import '../../core/models/app_settings.dart';
import '../../core/services/exception_log_service.dart';
import '../../core/services/settings_service.dart';
import '../main_screen.dart';
import 'app_bootstrap.dart';
import 'boot_app_shell.dart';
import 'boot_copy_feedback.dart';
import 'boot_failure_view.dart';
import 'boot_log_buffer.dart';
import 'booting_progress_view.dart';

/// 应用启动宿主，负责展示启动进度页并在成功后切入主界面。
class BootHostApp extends StatefulWidget {
  /// 可选的启动依赖覆盖，用于测试或自定义装配。
  final BootDependencies? bootDependencies;

  /// 创建一个可注入启动依赖的宿主应用。
  const BootHostApp({
    super.key,
    this.bootDependencies,
  });

  @override
  State<BootHostApp> createState() => _BootHostAppState();
}

class _BootHostAppState extends State<BootHostApp> with WidgetsBindingObserver {
  static const Duration _kTickerInterval = Duration(seconds: 1);
  static const int _kMaxLogLines = 160;
  static const int _kVisibleLogLines = 18;
  static const String _kBootStartStep = 'boot.start';

  late final BootLogBuffer _bootLogBuffer;
  late final BootDependencies _bootDependencies =
      widget.bootDependencies ?? BootDependencies.defaults();
  late final SettingsService _settingsService =
      _bootDependencies.settingsService;
  late final ExceptionLogService _exceptionLogService =
      _bootDependencies.exceptionLogService;
  Timer? _ticker;
  int _startedAtMs = 0;
  String _step = _kBootStartStep;

  BootFailure? _failure;
  bool _booting = true;
  bool _settingsReady = false;
  late Brightness _platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _bootLogBuffer = BootLogBuffer(
      maxLines: _kMaxLogLines,
      visibleLines: _kVisibleLogLines,
    );
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _activateBootLog('[boot-host] mounted');
    _startTicker();
    _scheduleBootstrap();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    BootLog.unbind();
    WidgetsBinding.instance.removeObserver(this);
    _removeSettingsListener();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _refreshUiState();
  }

  void _startTicker() {
    _ticker = Timer.periodic(_kTickerInterval, (_) {
      if (!mounted || !_booting) return;
      setState(() {});
    });
  }

  void _scheduleBootstrap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runBootstrap());
    });
  }

  void _removeSettingsListener() {
    if (!_settingsReady) return;
    _settingsService.appSettingsListenable
        .removeListener(_onAppSettingsChanged);
    _settingsReady = false;
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    _refreshUiState();
  }

  void _refreshUiState() {
    setState(() {});
    _applySystemUiOverlayStyle();
  }

  AppSettings get _currentAppSettings {
    if (_settingsReady) return _settingsService.appSettings;
    return const AppSettings();
  }

  Brightness get _effectiveBrightness {
    switch (_currentAppSettings.appearanceMode) {
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

  Brightness get _shellBrightness {
    if (_booting) return _platformBrightness;
    return _effectiveBrightness;
  }

  String get _shellKey => _booting ? 'boot' : 'main';

  void _applySystemUiOverlayStyle() {
    final brightness = _effectiveBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  void _appendLog(String message) {
    _bootLogBuffer.append(message);
    if (!mounted) return;
    setState(() {});
  }

  void _setStep(String step) {
    _step = step;
    _appendLog('[boot] step=$step');
  }

  void _resetBootstrapState() {
    setState(() {
      _failure = null;
      _booting = true;
      _step = _kBootStartStep;
      _startedAtMs = DateTime.now().millisecondsSinceEpoch;
      _bootLogBuffer.clear();
    });
  }

  Future<BootFailure?> _performBootstrap() async {
    try {
      return await bootstrapApp(
        onStepChanged: _setStep,
        dependencies: _bootDependencies,
      );
    } catch (error, stackTrace) {
      _appendLog('[boot-host] unexpected error: $error');
      _exceptionLogService.record(
        node: 'bootstrap.unexpected',
        message: '启动流程发生未捕获异常',
        error: error,
        stackTrace: stackTrace,
      );
      return BootFailure.unknown(
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleBootstrapSuccess() {
    _appendLog('[boot-host] bootstrap ok');
    BootLog.unbind();
    _bindSettingsListener();
    _applySystemUiOverlayStyle();
  }

  void _bindSettingsListener() {
    if (_settingsReady) return;
    _settingsReady = true;
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
  }

  void _handleBootstrapFailure(BootFailure failure) {
    _appendLog('[boot-host] bootstrap failed: ${failure.stepName}');
  }

  Future<void> _runBootstrap() async {
    _prepareBootstrapRun();

    final failure = await _performBootstrap();
    if (!mounted) return;

    _finishBootstrap(failure);
  }

  void _prepareBootstrapRun() {
    _removeSettingsListener();
    _resetBootstrapState();
    _activateBootLog('[boot-host] bootstrap begin');
  }

  void _activateBootLog(String initialMessage) {
    BootLog.bind(_appendLog);
    _appendLog(initialMessage);
  }

  void _finishBootstrap(BootFailure? failure) {
    if (failure == null) {
      _handleBootstrapSuccess();
    } else {
      _handleBootstrapFailure(failure);
    }

    setState(() {
      _failure = failure;
      _booting = false;
    });
  }

  void _retryBootstrap() {
    unawaited(_runBootstrap());
  }

  Future<void> _copyBootLog(BuildContext context) {
    return copyTextWithFeedback(
      context,
      text: _bootLogBuffer.payload(),
      successMessage: '启动日志已复制到剪贴板。',
    );
  }

  double get _elapsedSeconds {
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - _startedAtMs;
    return elapsedMs / 1000.0;
  }

  Widget _buildBootingHome() {
    return BootingProgressView(
      step: _step,
      elapsedSeconds: _elapsedSeconds,
      latestLogLine: _bootLogBuffer.latestLine(),
      bootLogTail: _bootLogBuffer.tailPayload(),
      hasLogs: _bootLogBuffer.hasLogs,
      onCopyLog: _copyBootLog,
    );
  }

  Widget _buildReadyHome() {
    final failure = _failure;
    if (failure != null) {
      return BootFailureView(
        failure: failure,
        retrying: false,
        onRetry: _retryBootstrap,
        bootLog: _bootLogBuffer.payload(),
      );
    }
    return MainScreen(
      brightness: _shellBrightness,
      appSettings: _currentAppSettings,
    );
  }

  Widget _buildCurrentHome() {
    if (_booting) return _buildBootingHome();
    return _buildReadyHome();
  }

  @override
  Widget build(BuildContext context) {
    return BootAppShell(
      shellKey: _shellKey,
      brightness: _shellBrightness,
      home: _buildCurrentHome(),
    );
  }
}
