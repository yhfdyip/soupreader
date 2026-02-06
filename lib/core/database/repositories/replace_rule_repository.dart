import '../../utils/legado_json.dart';
import '../../../features/replace/models/replace_rule.dart';
import '../database_service.dart';
import '../entities/book_entity.dart';

class ReplaceRuleRepository {
  final DatabaseService _db;

  ReplaceRuleRepository(this._db);

  List<ReplaceRule> getAllRules() {
    return _db.replaceRulesBox.values.map(_entityToModel).toList();
  }

  List<ReplaceRule> getEnabledRulesSorted() {
    final list = getAllRules().where((r) => r.isEnabled).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<void> addRule(ReplaceRule rule) async {
    await _db.replaceRulesBox.put(rule.id, _modelToEntity(rule));
  }

  Future<void> addRules(List<ReplaceRule> rules) async {
    final entries = <int, ReplaceRuleEntity>{};
    for (final rule in rules) {
      entries[rule.id] = _modelToEntity(rule);
    }
    await _db.replaceRulesBox.putAll(entries);
  }

  Future<void> updateRule(ReplaceRule rule) async {
    await addRule(rule);
  }

  Future<void> deleteRule(int id) async {
    await _db.replaceRulesBox.delete(id);
  }

  Future<void> deleteDisabledRules() async {
    final disabled = _db.replaceRulesBox.values
        .where((r) => !r.isEnabled)
        .map((r) => r.id)
        .toList(growable: false);
    await _db.replaceRulesBox.deleteAll(disabled);
  }

  String exportToJson(List<ReplaceRule> rules) {
    final payload = rules.map((r) => r.toJson()).toList(growable: false);
    return LegadoJson.encode(payload);
  }

  ReplaceRule _entityToModel(ReplaceRuleEntity entity) {
    return ReplaceRule(
      id: entity.id,
      name: entity.name,
      group: entity.group,
      pattern: entity.pattern,
      replacement: entity.replacement,
      scope: entity.scope,
      scopeTitle: entity.scopeTitle,
      scopeContent: entity.scopeContent,
      excludeScope: entity.excludeScope,
      isEnabled: entity.isEnabled,
      isRegex: entity.isRegex,
      timeoutMillisecond: entity.timeoutMillisecond,
      order: entity.order,
    );
  }

  ReplaceRuleEntity _modelToEntity(ReplaceRule rule) {
    return ReplaceRuleEntity(
      id: rule.id,
      name: rule.name,
      group: rule.group,
      pattern: rule.pattern,
      replacement: rule.replacement,
      scope: rule.scope,
      scopeTitle: rule.scopeTitle,
      scopeContent: rule.scopeContent,
      excludeScope: rule.excludeScope,
      isEnabled: rule.isEnabled,
      isRegex: rule.isRegex,
      timeoutMillisecond: rule.timeoutMillisecond,
      order: rule.order,
    );
  }
}

