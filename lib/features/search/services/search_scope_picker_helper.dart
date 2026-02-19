import '../../source/models/book_source.dart';

class SearchScopePickerHelper {
  const SearchScopePickerHelper._();

  static List<BookSource> filterSourcesByQuery(
    List<BookSource> sources,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return sources;
    return sources.where((source) {
      final name = source.bookSourceName.toLowerCase();
      final url = source.bookSourceUrl.toLowerCase();
      final group = (source.bookSourceGroup ?? '').toLowerCase();
      final comment = (source.bookSourceComment ?? '').toLowerCase();
      return name.contains(query) ||
          url.contains(query) ||
          group.contains(query) ||
          comment.contains(query);
    }).toList(growable: false);
  }

  static void toggleGroupSelection(List<String> selectedGroups, String group) {
    if (selectedGroups.contains(group)) {
      selectedGroups.remove(group);
    } else {
      selectedGroups.add(group);
    }
  }

  static List<String> orderedSelectedGroups(
    List<String> selectedGroups,
    List<String> allGroups,
  ) {
    return selectedGroups
        .where((group) => allGroups.contains(group))
        .toList(growable: false);
  }
}
