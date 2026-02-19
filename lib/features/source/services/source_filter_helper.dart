import '../models/book_source.dart';
import 'source_check_source_state_helper.dart';

enum SourceEnabledFilter {
  all,
  enabled,
  disabled,
}

class SourceFilterHelper {
  const SourceFilterHelper._();

  static final RegExp _splitGroupRegex = RegExp(r'[,;，；]');

  static List<String> buildGroups(List<BookSource> sources) {
    final groups = <String>{};
    for (final source in sources) {
      final raw = source.bookSourceGroup?.trim();
      if (raw == null || raw.isEmpty) continue;
      for (final g in raw.split(_splitGroupRegex)) {
        final group = g.trim();
        if (group.isNotEmpty) groups.add(group);
      }
    }
    return ['全部', ...groups.toList()..sort(), '失效'];
  }

  static List<BookSource> filterByGroup(
    List<BookSource> sources,
    String activeGroup,
  ) {
    if (activeGroup == '全部') return sources;
    if (activeGroup == '失效') {
      return sources.where((source) {
        final groups = SourceCheckSourceStateHelper.splitGroups(
          source.bookSourceGroup,
        );
        return groups.any(SourceCheckSourceStateHelper.isInvalidGroup);
      }).toList(growable: false);
    }
    return sources.where((s) {
      final raw = s.bookSourceGroup;
      if (raw == null || raw.trim().isEmpty) return false;
      return raw
          .split(_splitGroupRegex)
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .contains(activeGroup);
    }).toList(growable: false);
  }

  static List<BookSource> filterByEnabled(
    List<BookSource> sources,
    SourceEnabledFilter filter,
  ) {
    switch (filter) {
      case SourceEnabledFilter.all:
        return sources;
      case SourceEnabledFilter.enabled:
        return sources.where((s) => s.enabled).toList(growable: false);
      case SourceEnabledFilter.disabled:
        return sources.where((s) => !s.enabled).toList(growable: false);
    }
  }
}
