import '../models/book_source.dart';

class SourceCheckSourceStateHelper {
  const SourceCheckSourceStateHelper._();

  static final RegExp _splitGroupRegex = RegExp(r'[,;，；]');
  static const String _errorCommentPrefix = '// Error: ';

  static List<String> splitGroups(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return const <String>[];
    final groups = <String>{};
    for (final part in text.split(_splitGroupRegex)) {
      final group = part.trim();
      if (group.isEmpty) continue;
      groups.add(group);
    }
    return groups.toList(growable: false);
  }

  static bool isInvalidGroup(String group) {
    final text = group.trim();
    if (text.isEmpty) return false;
    return text == '校验超时' || text.contains('失效');
  }

  static String invalidGroupNames(String? raw) {
    return splitGroups(raw).where(isInvalidGroup).join(',');
  }

  static BookSource applyGroupMutations(
    BookSource source, {
    Iterable<String> add = const <String>{},
    Iterable<String> remove = const <String>{},
  }) {
    final groups = <String>{...splitGroups(source.bookSourceGroup)};
    final removeSet =
        remove.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final addSet = add.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

    if (removeSet.isEmpty && addSet.isEmpty) {
      return source;
    }

    groups.removeAll(removeSet);
    groups.addAll(addSet);
    final nextGroup = groups.join(',');
    final currentGroup = source.bookSourceGroup ?? '';
    if (currentGroup == nextGroup) {
      return source;
    }
    return source.copyWith(bookSourceGroup: nextGroup);
  }

  static BookSource removeInvalidGroups(BookSource source) {
    final invalid =
        splitGroups(source.bookSourceGroup).where(isInvalidGroup).toSet();
    if (invalid.isEmpty) return source;
    return applyGroupMutations(source, remove: invalid);
  }

  static BookSource removeErrorComment(BookSource source) {
    final comment = source.bookSourceComment;
    if (comment == null) return source;
    final cleaned = comment
        .split('\n\n')
        .where((block) => !block.startsWith(_errorCommentPrefix))
        .join('\n');
    if (cleaned == comment) return source;
    return source.copyWith(bookSourceComment: cleaned);
  }

  static BookSource addErrorComment(BookSource source, String message) {
    final text = message.trim();
    if (text.isEmpty) return source;
    final current = source.bookSourceComment ?? '';
    final nextComment = current.trim().isEmpty
        ? '$_errorCommentPrefix$text'
        : '$_errorCommentPrefix$text\n\n$current';
    return source.copyWith(bookSourceComment: nextComment);
  }

  static BookSource prepareForCheck(BookSource source) {
    return removeErrorComment(removeInvalidGroups(source));
  }
}
