import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../database/database_service.dart';

class ExceptionLogEntry {
  final String id;
  final int timestampMs;
  final String node;
  final String message;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic>? context;

  const ExceptionLogEntry({
    required this.id,
    required this.timestampMs,
    required this.node,
    required this.message,
    this.error,
    this.stackTrace,
    this.context,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'timestampMs': timestampMs,
      'node': node,
      'message': message,
      if (error != null) 'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (context != null) 'context': context,
    };
  }

  static ExceptionLogEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.map((key, value) => MapEntry('$key', value));
    final id = (map['id'] ?? '').toString().trim();
    final node = (map['node'] ?? '').toString().trim();
    final message = (map['message'] ?? '').toString().trim();
    final timestampRaw = map['timestampMs'];
    final timestampMs = timestampRaw is num
        ? timestampRaw.toInt()
        : int.tryParse('$timestampRaw') ?? 0;
    if (id.isEmpty || node.isEmpty || message.isEmpty || timestampMs <= 0) {
      return null;
    }

    final contextRaw = map['context'];
    Map<String, dynamic>? context;
    if (contextRaw is Map) {
      context = contextRaw.map((key, value) => MapEntry('$key', value));
    }

    return ExceptionLogEntry(
      id: id,
      timestampMs: timestampMs,
      node: node,
      message: message,
      error: map['error']?.toString(),
      stackTrace: map['stackTrace']?.toString(),
      context: context,
    );
  }
}

/// 对标 legado AppLog：记录关键异常并提供 UI 查看入口。
class ExceptionLogService {
  static final ExceptionLogService _instance = ExceptionLogService._internal();
  factory ExceptionLogService() => _instance;
  ExceptionLogService._internal();

  static const String _storageKey = 'dev_exception_logs_v1';
  static const int _maxEntries = 200;

  final List<ExceptionLogEntry> _entries = <ExceptionLogEntry>[];
  final ValueNotifier<List<ExceptionLogEntry>> _entriesNotifier =
      ValueNotifier<List<ExceptionLogEntry>>(const <ExceptionLogEntry>[]);

  bool _bootstrapped = false;
  bool _persisting = false;
  bool _dirty = false;
  int _seq = 0;

  ValueListenable<List<ExceptionLogEntry>> get listenable => _entriesNotifier;

  List<ExceptionLogEntry> get entries => List<ExceptionLogEntry>.unmodifiable(
        _entries,
      );

  int get count => _entries.length;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;

    final runtimeEntries = List<ExceptionLogEntry>.from(_entries);
    final storedEntries = await _loadFromStorage();
    final merged = <ExceptionLogEntry>[...runtimeEntries, ...storedEntries];
    merged.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

    final unique = <String>{};
    _entries
      ..clear()
      ..addAll(
        merged.where((item) {
          if (unique.contains(item.id)) return false;
          unique.add(item.id);
          return true;
        }).take(_maxEntries),
      );
    _emit();

    _bootstrapped = true;
    _requestPersist();
  }

  void record({
    required String node,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeNode = node.trim().isEmpty ? 'unknown' : node.trim();
    final safeMessage = message.trim().isEmpty ? '异常' : message.trim();
    final normalizedContext = _normalizeContext(context);

    final entry = ExceptionLogEntry(
      id: '${now}_${_seq++}_${Random().nextInt(1 << 20)}',
      timestampMs: now,
      node: safeNode,
      message: safeMessage,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      context: normalizedContext.isEmpty ? null : normalizedContext,
    );

    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    _emit();
    _requestPersist();
  }

  Future<void> clear() async {
    _entries.clear();
    _emit();
    if (!_bootstrapped) return;
    try {
      await DatabaseService().deleteSetting(_storageKey);
    } catch (_) {
      // ignore
    }
  }

  Future<List<ExceptionLogEntry>> _loadFromStorage() async {
    try {
      final raw = DatabaseService().getSetting(
        _storageKey,
        defaultValue: const <dynamic>[],
      );
      if (raw is! List) return const <ExceptionLogEntry>[];
      return raw
          .map(ExceptionLogEntry.fromJson)
          .whereType<ExceptionLogEntry>()
          .toList(growable: false);
    } catch (_) {
      return const <ExceptionLogEntry>[];
    }
  }

  Map<String, dynamic> _normalizeContext(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) return const <String, dynamic>{};
    final out = <String, dynamic>{};
    for (final entry in context.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value == null ||
          value is num ||
          value is bool ||
          value is String ||
          value is List ||
          value is Map) {
        out[key] = value;
      } else {
        out[key] = value.toString();
      }
    }
    return out;
  }

  void _emit() {
    _entriesNotifier.value = List<ExceptionLogEntry>.unmodifiable(_entries);
  }

  void _requestPersist() {
    if (!_bootstrapped) return;
    _dirty = true;
    if (_persisting) return;
    unawaited(_persistLoop());
  }

  Future<void> _persistLoop() async {
    _persisting = true;
    try {
      while (_dirty) {
        _dirty = false;
        try {
          await DatabaseService().putSetting(
            _storageKey,
            _entries.map((item) => item.toJson()).toList(growable: false),
          );
        } catch (_) {
          // ignore
        }
      }
    } finally {
      _persisting = false;
    }
  }
}

