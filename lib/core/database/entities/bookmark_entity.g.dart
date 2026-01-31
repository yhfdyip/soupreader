// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookmarkEntityAdapter extends TypeAdapter<BookmarkEntity> {
  @override
  final int typeId = 3;

  @override
  BookmarkEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookmarkEntity(
      id: fields[0] as String,
      bookId: fields[1] as String,
      bookName: fields[2] as String,
      bookAuthor: fields[3] as String,
      chapterIndex: fields[4] as int,
      chapterTitle: fields[5] as String,
      chapterPos: fields[6] as int,
      content: fields[7] as String,
      createdTime: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BookmarkEntity obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.bookName)
      ..writeByte(3)
      ..write(obj.bookAuthor)
      ..writeByte(4)
      ..write(obj.chapterIndex)
      ..writeByte(5)
      ..write(obj.chapterTitle)
      ..writeByte(6)
      ..write(obj.chapterPos)
      ..writeByte(7)
      ..write(obj.content)
      ..writeByte(8)
      ..write(obj.createdTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
