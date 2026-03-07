import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/preferences_store.dart';
import '../models/rule_subscription.dart';

class RuleSubscriptionStore {
  static const String _prefsKey = 'rule_subscriptions';

  RuleSubscriptionStore({
    PreferencesStore? preferencesStore,
  }) : _preferencesStore = preferencesStore ?? defaultPreferencesStore;

  final ValueNotifier<List<RuleSubscription>> _listenable =
      ValueNotifier<List<RuleSubscription>>(const <RuleSubscription>[]);
  final PreferencesStore _preferencesStore;

  bool _initialized = false;

  ValueListenable<List<RuleSubscription>> get listenable => _listenable;

  List<RuleSubscription> get items =>
      List<RuleSubscription>.unmodifiable(_listenable.value);

  int get nextCustomOrder {
    var maxOrder = 0;
    for (final item in _listenable.value) {
      if (item.customOrder > maxOrder) {
        maxOrder = item.customOrder;
      }
    }
    return maxOrder + 1;
  }

  int get nextId {
    final now = DateTime.now().millisecondsSinceEpoch;
    var maxId = 0;
    for (final item in _listenable.value) {
      if (item.id > maxId) {
        maxId = item.id;
      }
    }
    return now > maxId ? now : maxId + 1;
  }

  RuleSubscription? findByUrl(String url) {
    for (final item in _listenable.value) {
      if (item.url == url) {
        return item;
      }
    }
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _reload();
  }

  Future<void> reload() async {
    await _reload();
  }

  Future<void> delete(RuleSubscription subscription) async {
    final current = items;
    if (current.isEmpty) return;
    final next = current
        .where((item) => item.id != subscription.id)
        .toList(growable: false);
    if (next.length == current.length) return;
    await _save(next);
  }

  Future<void> upsert(RuleSubscription subscription) async {
    final current = items;
    var replaced = false;
    final next = <RuleSubscription>[];
    for (final item in current) {
      if (item.id == subscription.id) {
        next.add(subscription);
        replaced = true;
      } else {
        next.add(item);
      }
    }
    if (!replaced) {
      next.add(subscription);
    }
    await _save(next);
  }

  void dispose() {
    _listenable.dispose();
  }

  Future<void> _reload() async {
    final raw = (await _preferencesStore.getString(_prefsKey))?.trim();
    if (raw == null || raw.isEmpty) {
      _listenable.value = const <RuleSubscription>[];
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _listenable.value = const <RuleSubscription>[];
        return;
      }
      final parsed = decoded
          .map(RuleSubscription.fromJson)
          .whereType<RuleSubscription>()
          .toList(growable: false)
        ..sort(_compareRuleSubscription);
      _listenable.value = parsed;
    } catch (_) {
      _listenable.value = const <RuleSubscription>[];
    }
  }

  Future<void> _save(List<RuleSubscription> subscriptions) async {
    final normalized = subscriptions.toList(growable: false)
      ..sort(_compareRuleSubscription);
    await _preferencesStore.setString(
      _prefsKey,
      jsonEncode(
        normalized
            .map((subscription) => subscription.toJson())
            .toList(growable: false),
      ),
    );
    _listenable.value = normalized;
  }

  static int _compareRuleSubscription(
    RuleSubscription a,
    RuleSubscription b,
  ) {
    final orderCompare = a.customOrder.compareTo(b.customOrder);
    if (orderCompare != 0) return orderCompare;
    return a.id.compareTo(b.id);
  }
}
