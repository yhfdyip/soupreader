// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookEntityAdapter extends TypeAdapter<BookEntity> {
  @override
  final int typeId = 0;

  @override
  BookEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookEntity(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      coverUrl: fields[3] as String?,
      intro: fields[4] as String?,
      sourceId: fields[5] as String?,
      sourceUrl: fields[6] as String?,
      latestChapter: fields[7] as String?,
      totalChapters: fields[8] as int,
      currentChapter: fields[9] as int,
      readProgress: fields[10] as double,
      lastReadTime: fields[11] as DateTime?,
      addedTime: fields[12] as DateTime?,
      isLocal: fields[13] as bool,
      localPath: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BookEntity obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.coverUrl)
      ..writeByte(4)
      ..write(obj.intro)
      ..writeByte(5)
      ..write(obj.sourceId)
      ..writeByte(6)
      ..write(obj.sourceUrl)
      ..writeByte(7)
      ..write(obj.latestChapter)
      ..writeByte(8)
      ..write(obj.totalChapters)
      ..writeByte(9)
      ..write(obj.currentChapter)
      ..writeByte(10)
      ..write(obj.readProgress)
      ..writeByte(11)
      ..write(obj.lastReadTime)
      ..writeByte(12)
      ..write(obj.addedTime)
      ..writeByte(13)
      ..write(obj.isLocal)
      ..writeByte(14)
      ..write(obj.localPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChapterEntityAdapter extends TypeAdapter<ChapterEntity> {
  @override
  final int typeId = 1;

  @override
  ChapterEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChapterEntity(
      id: fields[0] as String,
      bookId: fields[1] as String,
      title: fields[2] as String,
      url: fields[3] as String?,
      index: fields[4] as int,
      isDownloaded: fields[5] as bool,
      content: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChapterEntity obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.url)
      ..writeByte(4)
      ..write(obj.index)
      ..writeByte(5)
      ..write(obj.isDownloaded)
      ..writeByte(6)
      ..write(obj.content);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookSourceEntityAdapter extends TypeAdapter<BookSourceEntity> {
  @override
  final int typeId = 2;

  @override
  BookSourceEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookSourceEntity(
      bookSourceUrl: fields[0] as String,
      bookSourceName: fields[1] as String,
      bookSourceGroup: fields[2] as String?,
      bookSourceType: fields[3] as int,
      enabled: fields[4] as bool,
      ruleSearchJson: fields[5] as String?,
      ruleBookInfoJson: fields[6] as String?,
      ruleTocJson: fields[7] as String?,
      ruleContentJson: fields[8] as String?,
      bookSourceComment: fields[9] as String?,
      weight: fields[10] as int? ?? 0,
      header: fields[11] as String?,
      loginUrl: fields[12] as String?,
      lastUpdateTime: fields[13] as DateTime?,
      rawJson: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BookSourceEntity obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.bookSourceUrl)
      ..writeByte(1)
      ..write(obj.bookSourceName)
      ..writeByte(2)
      ..write(obj.bookSourceGroup)
      ..writeByte(3)
      ..write(obj.bookSourceType)
      ..writeByte(4)
      ..write(obj.enabled)
      ..writeByte(5)
      ..write(obj.ruleSearchJson)
      ..writeByte(6)
      ..write(obj.ruleBookInfoJson)
      ..writeByte(7)
      ..write(obj.ruleTocJson)
      ..writeByte(8)
      ..write(obj.ruleContentJson)
      ..writeByte(9)
      ..write(obj.bookSourceComment)
      ..writeByte(10)
      ..write(obj.weight)
      ..writeByte(11)
      ..write(obj.header)
      ..writeByte(12)
      ..write(obj.loginUrl)
      ..writeByte(13)
      ..write(obj.lastUpdateTime)
      ..writeByte(14)
      ..write(obj.rawJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookSourceEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReplaceRuleEntityAdapter extends TypeAdapter<ReplaceRuleEntity> {
  @override
  final int typeId = 3;

  @override
  ReplaceRuleEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReplaceRuleEntity(
      id: fields[0] as int,
      name: fields[1] as String,
      group: fields[2] as String?,
      pattern: fields[3] as String,
      replacement: fields[4] as String,
      scope: fields[5] as String?,
      scopeTitle: fields[6] as bool,
      scopeContent: fields[7] as bool,
      excludeScope: fields[8] as String?,
      isEnabled: fields[9] as bool,
      isRegex: fields[10] as bool,
      timeoutMillisecond: fields[11] as int,
      order: fields[12] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ReplaceRuleEntity obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.group)
      ..writeByte(3)
      ..write(obj.pattern)
      ..writeByte(4)
      ..write(obj.replacement)
      ..writeByte(5)
      ..write(obj.scope)
      ..writeByte(6)
      ..write(obj.scopeTitle)
      ..writeByte(7)
      ..write(obj.scopeContent)
      ..writeByte(8)
      ..write(obj.excludeScope)
      ..writeByte(9)
      ..write(obj.isEnabled)
      ..writeByte(10)
      ..write(obj.isRegex)
      ..writeByte(11)
      ..write(obj.timeoutMillisecond)
      ..writeByte(12)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplaceRuleEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
