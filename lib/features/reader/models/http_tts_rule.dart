import 'dart:convert';

import '../../../core/utils/legado_json.dart';

class HttpTtsRule {
  final int id;
  final String name;
  final String url;
  final String? contentType;
  final String? concurrentRate;
  final String? loginUrl;
  final String? loginUi;
  final String? header;
  final String? jsLib;
  final bool? enabledCookieJar;
  final String? loginCheckJs;
  final int lastUpdateTime;

  const HttpTtsRule({
    required this.id,
    required this.name,
    required this.url,
    required this.contentType,
    required this.concurrentRate,
    required this.loginUrl,
    required this.loginUi,
    required this.header,
    required this.jsLib,
    required this.enabledCookieJar,
    required this.loginCheckJs,
    required this.lastUpdateTime,
  });

  bool get isDefaultRule => id < 0;

  HttpTtsRule copyWith({
    int? id,
    String? name,
    String? url,
    String? contentType,
    String? concurrentRate,
    String? loginUrl,
    String? loginUi,
    String? header,
    String? jsLib,
    bool? enabledCookieJar,
    String? loginCheckJs,
    int? lastUpdateTime,
  }) {
    return HttpTtsRule(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      contentType: contentType ?? this.contentType,
      concurrentRate: concurrentRate ?? this.concurrentRate,
      loginUrl: loginUrl ?? this.loginUrl,
      loginUi: loginUi ?? this.loginUi,
      header: header ?? this.header,
      jsLib: jsLib ?? this.jsLib,
      enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
      loginCheckJs: loginCheckJs ?? this.loginCheckJs,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  factory HttpTtsRule.fromJson(Map<String, dynamic> json) {
    final id = _toInt(
          json['id'],
          fallback: DateTime.now().millisecondsSinceEpoch,
        ) ??
        DateTime.now().millisecondsSinceEpoch;
    final name = _toTrimmedString(json['name']);
    final url = _toTrimmedString(json['url']);
    return HttpTtsRule(
      id: id,
      name: name,
      url: url,
      contentType: _toNullableTrimmedString(json['contentType']),
      concurrentRate: _toNullableTrimmedString(json['concurrentRate']),
      loginUrl: _toNullableTrimmedString(json['loginUrl']),
      loginUi: _toNullableTrimmedString(json['loginUi']),
      header: _toNullableTrimmedString(json['header']),
      jsLib: _toNullableTrimmedString(json['jsLib']),
      enabledCookieJar: _toBool(json['enabledCookieJar']),
      loginCheckJs: _toNullableTrimmedString(json['loginCheckJs']),
      lastUpdateTime: _toInt(
            json['lastUpdateTime'],
            fallback: DateTime.now().millisecondsSinceEpoch,
          ) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
      'contentType': contentType,
      'concurrentRate': concurrentRate,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'header': header,
      'jsLib': jsLib,
      'enabledCookieJar': enabledCookieJar,
      'loginCheckJs': loginCheckJs,
      'lastUpdateTime': lastUpdateTime,
    };
  }

  static List<HttpTtsRule> listFromJsonText(String text) {
    final dynamic decoded = json.decode(text);
    final items = <dynamic>[];
    if (decoded is List) {
      items.addAll(decoded);
    } else if (decoded is Map) {
      items.add(decoded);
    } else {
      throw const FormatException('JSON 格式不支持');
    }
    final rules = <HttpTtsRule>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        rules.add(HttpTtsRule.fromJson(item));
        continue;
      }
      if (item is Map) {
        rules.add(HttpTtsRule.fromJson(
          item.map((key, value) => MapEntry('$key', value)),
        ));
      }
    }
    return rules;
  }

  static String listToJsonText(List<HttpTtsRule> rules) {
    return LegadoJson.encode(
      rules.map((rule) => rule.toJson()).toList(growable: false),
    );
  }

  static String _toTrimmedString(dynamic value) {
    if (value == null) return '';
    final text = '$value'.trim();
    return text;
  }

  static String? _toNullableTrimmedString(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    if (text.isEmpty) return null;
    return text;
  }

  static int? _toInt(dynamic value, {int? fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.round();
    final parsed = int.tryParse('$value'.trim());
    return parsed ?? fallback;
  }

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }
}
