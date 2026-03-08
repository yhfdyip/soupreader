import 'dart:convert';

import '../../../core/database/database_service.dart';
import '../models/bookshelf_book_group.dart';

class BookshelfBookGroupStore {
  BookshelfBookGroupStore({DatabaseService? database})
      : _database = database ?? DatabaseService();

  static const String _settingKey = 'bookshelf.book_groups';
  static const int _maxCustomGroupCount = 64;

  static const List<BookshelfBookGroup> _legacyBuiltinGroups =
      <BookshelfBookGroup>[
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idAll,
      groupName: '全部',
      show: true,
      order: -10,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idLocal,
      groupName: '本地',
      show: true,
      order: -9,
      bookSort: -1,
      enableRefresh: false,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idAudio,
      groupName: '音频',
      show: true,
      order: -8,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idNetNone,
      groupName: '网络未分组',
      show: true,
      order: -7,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idLocalNone,
      groupName: '本地未分组',
      show: false,
      order: -6,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idError,
      groupName: '更新失败',
      show: true,
      order: -1,
      bookSort: -1,
      enableRefresh: true,
    ),
  ];

  final DatabaseService _database;

  Future<List<BookshelfBookGroup>> getGroups() async {
    final raw = _database.getSetting(_settingKey);
    final parsedGroups = _parseRawGroups(raw);
    final byId = <int, BookshelfBookGroup>{};
    for (final group in parsedGroups) {
      byId[group.groupId] = group;
    }
    var changed = raw is! List || byId.length != parsedGroups.length;
    for (final builtin in _legacyBuiltinGroups) {
      if (byId.containsKey(builtin.groupId)) continue;
      byId[builtin.groupId] = builtin;
      changed = true;
    }
    final groups = _sortGroups(byId.values);
    if (changed) {
      await _saveGroupsInternal(groups);
    }
    return groups;
  }

  Future<bool> canAddGroup() async {
    final groups = await getGroups();
    final count = groups
        .where(
          (group) =>
              group.groupId >= 0 ||
              group.groupId == BookshelfBookGroup.longMinValue,
        )
        .length;
    return count < _maxCustomGroupCount;
  }

  Future<BookshelfBookGroup> addGroup(
    String groupName, {
    String? cover,
    int bookSort = -1,
    bool enableRefresh = true,
  }) async {
    final normalizedName = groupName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('分组名称不能为空');
    }
    final normalizedCover = (cover ?? '').trim();
    final groups = await getGroups();
    final customCount = groups
        .where(
          (group) =>
              group.groupId >= 0 ||
              group.groupId == BookshelfBookGroup.longMinValue,
        )
        .length;
    if (customCount >= _maxCustomGroupCount) {
      throw StateError('分组已达上限(64个)');
    }
    final groupId = _resolveUnusedGroupId(groups);
    final maxOrder = _resolveMaxCustomOrder(groups);
    final created = BookshelfBookGroup(
      groupId: groupId,
      groupName: normalizedName,
      show: true,
      order: maxOrder + 1,
      cover: normalizedCover.isEmpty ? null : normalizedCover,
      bookSort: bookSort,
      enableRefresh: enableRefresh,
    );
    final nextGroups = <BookshelfBookGroup>[...groups, created];
    await saveGroups(nextGroups);
    return created;
  }

  Future<void> updateGroup(BookshelfBookGroup updated) async {
    final groups = await getGroups();
    final next = groups.map((g) => g.groupId == updated.groupId ? updated : g).toList();
    await saveGroups(next);
  }

  Future<void> deleteGroup(int groupId) async {
    final groups = await getGroups();
    final next = groups.where((g) => g.groupId != groupId).toList();
    await saveGroups(next);
  }

  Future<void> saveGroups(List<BookshelfBookGroup> groups) async {
    final normalized = _sortGroups(groups);
    await _saveGroupsInternal(normalized);
  }

  Future<void> _saveGroupsInternal(List<BookshelfBookGroup> groups) {
    return _database.putSetting(
      _settingKey,
      groups.map((group) => group.toJson()).toList(growable: false),
    );
  }

  List<BookshelfBookGroup> _parseRawGroups(dynamic raw) {
    if (raw is! List) return const <BookshelfBookGroup>[];
    return BookshelfBookGroup.listFromJsonText(json.encode(raw));
  }

  List<BookshelfBookGroup> _sortGroups(Iterable<BookshelfBookGroup> groups) {
    final byId = <int, BookshelfBookGroup>{};
    for (final group in groups) {
      byId[group.groupId] = group;
    }
    final sorted = byId.values.toList(growable: false);
    sorted.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.groupId.compareTo(b.groupId);
    });
    return sorted;
  }

  int _resolveUnusedGroupId(List<BookshelfBookGroup> groups) {
    var usedIds = 0;
    for (final group in groups) {
      if (group.groupId > 0) {
        usedIds |= group.groupId;
      }
    }
    var candidate = 1;
    while ((candidate & usedIds) != 0) {
      candidate = candidate << 1;
    }
    return candidate;
  }

  int _resolveMaxCustomOrder(List<BookshelfBookGroup> groups) {
    var maxOrder = 0;
    for (final group in groups) {
      if (group.groupId >= 0 && group.order > maxOrder) {
        maxOrder = group.order;
      }
    }
    return maxOrder;
  }
}
