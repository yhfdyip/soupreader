import '../../source/models/book_source.dart';

/// 搜索范围语义（对齐 legado）：
/// - `""`：全部书源
/// - `"分组A,分组B"`：分组模式
/// - `"书源名::书源URL"`：单源模式
class SearchScope {
  static final RegExp _splitGroupRegex = RegExp(r'[,;，；]');

  final String scope;

  const SearchScope(this.scope);

  bool get isAll => scope.trim().isEmpty;

  bool get isSource => scope.contains('::');

  String get normalizedText => normalizeScopeText(scope);

  String display({String allLabel = '全部书源'}) {
    if (isSource) {
      final name = _substringBefore(scope, '::').trim();
      if (name.isNotEmpty) return name;
      return _substringAfter(scope, '::').trim();
    }
    final text = scope.trim();
    if (text.isEmpty) return allLabel;
    return text;
  }

  List<String> get displayNames {
    if (isSource) {
      final name = _substringBefore(scope, '::').trim();
      if (name.isEmpty) return const <String>[];
      return <String>[name];
    }
    return splitNotBlank(scope);
  }

  SearchScopeResolveResult resolve(
    List<BookSource> enabledSources, {
    List<BookSource>? allSourcesForSourceMode,
  }) {
    final sortedEnabledSources = _sortByOrder(enabledSources);
    final sortedAllSources =
        _sortByOrder(allSourcesForSourceMode ?? enabledSources);
    final currentScope = normalizedText;
    if (currentScope.isEmpty) {
      return SearchScopeResolveResult(
        normalizedScope: '',
        sources: sortedEnabledSources,
        selectedGroups: const <String>[],
        selectedSource: null,
        sourceDisplayName: '',
      );
    }

    if (currentScope.contains('::')) {
      final displayName = _substringBefore(currentScope, '::').trim();
      final sourceUrl = _substringAfter(currentScope, '::').trim();
      final selected = sortedAllSources.where((item) {
        return item.bookSourceUrl.trim() == sourceUrl;
      }).toList(growable: false);
      if (selected.isEmpty) {
        return SearchScopeResolveResult(
          normalizedScope: '',
          sources: sortedEnabledSources,
          selectedGroups: const <String>[],
          selectedSource: null,
          sourceDisplayName: '',
        );
      }
      final source = selected.first;
      final finalName = displayName.isNotEmpty
          ? displayName
          : source.bookSourceName.replaceAll(':', '').trim();
      return SearchScopeResolveResult(
        normalizedScope: '$finalName::${source.bookSourceUrl.trim()}',
        sources: selected,
        selectedGroups: const <String>[],
        selectedSource: source,
        sourceDisplayName: finalName,
      );
    }

    final oldGroups = splitNotBlank(currentScope);
    final selectedGroups = <String>[];
    final selectedByUrl = <String, BookSource>{};
    for (final group in oldGroups) {
      final sourcesInGroup = sortedEnabledSources.where((source) {
        final sourceGroups = splitSourceGroups(source.bookSourceGroup);
        return sourceGroups.contains(group);
      }).toList(growable: false);
      if (sourcesInGroup.isEmpty) continue;
      selectedGroups.add(group);
      for (final source in sourcesInGroup) {
        final selectedUrl = source.bookSourceUrl.trim();
        if (selectedUrl.isEmpty) continue;
        selectedByUrl.putIfAbsent(selectedUrl, () => source);
      }
    }
    if (selectedByUrl.isEmpty) {
      return SearchScopeResolveResult(
        normalizedScope: '',
        sources: sortedEnabledSources,
        selectedGroups: const <String>[],
        selectedSource: null,
        sourceDisplayName: '',
      );
    }
    final scopedSources = _sortByOrder(selectedByUrl.values.toList());
    return SearchScopeResolveResult(
      normalizedScope: selectedGroups.join(','),
      sources: scopedSources,
      selectedGroups: selectedGroups,
      selectedSource: null,
      sourceDisplayName: '',
    );
  }

  static String normalizeScopeText(String raw) {
    return raw.trim();
  }

  static String fromGroups(Iterable<String> groups) {
    return groups
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join(',');
  }

  static String fromSource(BookSource source) {
    final name = source.bookSourceName.replaceAll(':', '').trim();
    final sourceUrl = source.bookSourceUrl.trim();
    return '$name::$sourceUrl';
  }

  static List<String> splitSourceGroups(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return const <String>[];
    return text
        .split(_splitGroupRegex)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> splitNotBlank(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<BookSource> _sortByOrder(List<BookSource> sources) {
    final indexed = sources.asMap().entries.toList(growable: false)
      ..sort((a, b) {
        final orderCompare = a.value.customOrder.compareTo(b.value.customOrder);
        if (orderCompare != 0) return orderCompare;
        return a.key.compareTo(b.key);
      });
    return indexed.map((item) => item.value).toList(growable: false);
  }

  static String _substringBefore(String text, String separator) {
    final index = text.indexOf(separator);
    if (index < 0) return text;
    return text.substring(0, index);
  }

  static String _substringAfter(String text, String separator) {
    final index = text.indexOf(separator);
    if (index < 0) return '';
    return text.substring(index + separator.length);
  }
}

class SearchScopeResolveResult {
  final String normalizedScope;
  final List<BookSource> sources;
  final List<String> selectedGroups;
  final BookSource? selectedSource;
  final String sourceDisplayName;

  const SearchScopeResolveResult({
    required this.normalizedScope,
    required this.sources,
    required this.selectedGroups,
    required this.selectedSource,
    required this.sourceDisplayName,
  });

  bool get isAll => normalizedScope.isEmpty;

  bool get isSource => normalizedScope.contains('::');

  String display({String allLabel = '全部书源'}) {
    if (isSource) {
      if (sourceDisplayName.isNotEmpty) return sourceDisplayName;
      final selectedName = selectedSource?.bookSourceName.trim() ?? '';
      if (selectedName.isNotEmpty) {
        return selectedName.replaceAll(':', '');
      }
      final url = SearchScope._substringAfter(normalizedScope, '::').trim();
      if (url.isNotEmpty) return url;
      return allLabel;
    }
    if (isAll) return allLabel;
    return selectedGroups.join(',');
  }

  List<String> get displayNames {
    if (isSource) {
      final name = display(allLabel: '').trim();
      if (name.isEmpty) return const <String>[];
      return <String>[name];
    }
    return selectedGroups;
  }
}
