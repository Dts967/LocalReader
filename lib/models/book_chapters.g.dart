// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_chapters.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookChaptersAdapter extends TypeAdapter<BookChapters> {
  @override
  final int typeId = 3;

  @override
  BookChapters read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookChapters(
      content: fields[1] as String,
    )
      ..chapters = ((fields[2] as List?) ?? const []).cast<String>()
      ..offsets = ((fields[3] as List?) ?? const []).cast<int>()
      ..titles = ((fields[4] as List?) ?? const []).cast<String>()
      ..pattern = fields[5] as String?
      ..mode = (fields[6] as String?) ?? 'auto';
  }

  @override
  void write(BinaryWriter writer, BookChapters obj) {
    writer
      ..writeByte(6)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.chapters)
      ..writeByte(3)
      ..write(obj.offsets)
      ..writeByte(4)
      ..write(obj.titles)
      ..writeByte(5)
      ..write(obj.pattern)
      ..writeByte(6)
      ..write(obj.mode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookChaptersAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
