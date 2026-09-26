// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 0;

  @override
  Book read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Book(
      title: fields[0] as String,
      filePath: (fields[4] as String?) ?? '',
      sourceType: (fields[5] as String?) ?? 'txt',
      author: (fields[6] as String?) ?? '',
      description: (fields[7] as String?) ?? '',
      coverPath: fields[8] as String?,
    )
      ..lastReadChapterIndex = (fields[1] as int?) ?? 0
      ..lastReadPosition = (fields[2] as int?) ?? 0
      ..lastReadTime = fields[3] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.lastReadChapterIndex)
      ..writeByte(2)
      ..write(obj.lastReadPosition)
      ..writeByte(3)
      ..write(obj.lastReadTime)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.sourceType)
      ..writeByte(6)
      ..write(obj.author)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.coverPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
