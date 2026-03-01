import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../app/theme/cupertino_theme.dart';
import '../../core/bootstrap/boot_log.dart';
import '../../core/services/exception_log_service.dart';
import '../soup_reader_app.dart';
import 'app_bootstrap.dart';
import 'boot_failure_view.dart';

class BootHostApp extends StatefulWidget {
  const BootHostApp({super.key});

  @override
  State<BootHostApp> createState() => _BootHostAppState();
}

class _BootHostAppState extends State<BootHostApp> {
  static const Duration _kTickerInterval = Duration(seconds: 1);
  static const int _kMaxLogLines = 160;

  final List<String> _logLines = <String>[];
  Timer? _ticker;
  int _startedAtMs = 0;
  String _step = 'boot.start';

  BootFailure? _failure;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
    setState(() {
      _failure = failure;
      _booting = false;
    });

    if (failure == null) {
      _appendLog('[boot-host] bootstrap ok');
      BootLog.unbind();
    } else {
      _appendLog('[boot-host] bootstrap failed: ${failure.stepName}');
    }
  }

  String _bootLogPayload() => _logLines.join('\n').trim();

  CupertinoApp _buildBootingApp() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final theme = AppCupertinoTheme.build(brightness);
    final elapsedSeconds =
        (DateTime.now().millisecondsSinceEpoch - _startedAtMs) / 1000.0;

    return CupertinoApp(
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      theme: theme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: Builder(
        builder: (innerContext) {
          return CupertinoPageScaffold(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  const SizedBox(height: 6),
                  const Center(child: CupertinoActivityIndicator()),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      '正在初始化…',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '步骤：$_step',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '已用时：${elapsedSeconds.toStringAsFixed(0)}s',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.tertiaryLabel,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_logLines.isNotEmpty) ...[
                    const Text(
                      '启动日志',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemGroupedBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              CupertinoColors.separator.withValues(alpha: 0.7),
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _bootLogPayload(),
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CupertinoButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _bootLogPayload()),
                        );
                        if (!innerContext.mounted) return;
                        await showCupertinoDialog<void>(
                          context: innerContext,
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
                      },
                      child: const Text('复制启动日志'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (_booting) {
      return _buildBootingApp();
    }
    if (failure != null) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final theme = AppCupertinoTheme.build(brightness);
      return CupertinoApp(
        title: 'SoupReader',
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        home: BootFailureView(
          failure: failure,
          retrying: false,
          onRetry: () => unawaited(_runBootstrap()),
          bootLog: _bootLogPayload(),
        ),
      );
    }
    return const SoupReaderApp();
  }
}
