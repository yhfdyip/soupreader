import 'dart:convert';

import '../../../core/utils/legado_json.dart';

class DictRule {
  final String name;
  final String urlRule;
  final String showRule;
  final bool enabled;
  final int sortNumber;

  const DictRule({
    required this.name,
    required this.urlRule,
    required this.showRule,
    required this.enabled,
    required this.sortNumber,
  });

  DictRule copyWith({
    String? name,
    String? urlRule,
    String? showRule,
    bool? enabled,
    int? sortNumber,
  }) {
    return DictRule(
      name: name ?? this.name,
      urlRule: urlRule ?? this.urlRule,
      showRule: showRule ?? this.showRule,
      enabled: enabled ?? this.enabled,
      sortNumber: sortNumber ?? this.sortNumber,
    );
  }

  factory DictRule.fromJson(Map<String, dynamic> json) {
    return DictRule(
      name: _toStringOrEmpty(json['name']),
      urlRule: _toStringOrEmpty(json['urlRule']),
      showRule: _toStringOrEmpty(json['showRule']),
      enabled: _toBool(json['enabled'], fallback: true),
      sortNumber: _toInt(json['sortNumber']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'urlRule': urlRule,
      'showRule': showRule,
      'enabled': enabled,
      'sortNumber': sortNumber,
    };
  }

  static List<DictRule> listFromJsonText(String text) {
    final dynamic decoded = json.decode(text);
    final items = <dynamic>[];
    if (decoded is List) {
      items.addAll(decoded);
    } else if (decoded is Map) {
      items.add(decoded);
    } else {
      throw const FormatException('JSON 格式不支持');
    }
    final rules = <DictRule>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        rules.add(DictRule.fromJson(item));
        continue;
      }
      if (item is Map) {
        rules.add(
          DictRule.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        );
      }
    }
    return rules;
  }

  static String listToJsonText(List<DictRule> rules) {
    return LegadoJson.encode(
      rules.map((rule) => rule.toJson()).toList(growable: false),
    );
  }

  static String _toStringOrEmpty(dynamic value) {
    if (value == null) return '';
    return '$value'.trim();
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value'.trim()) ?? 0;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }
}
