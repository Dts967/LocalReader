// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReaderSettingsAdapter extends TypeAdapter<ReaderSettings> {
  @override
  final int typeId = 1;

  @override
  ReaderSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReaderSettings(
      fontSize: (fields[0] as num?)?.toDouble() ?? 18,
      lineHeight: (fields[1] as num?)?.toDouble() ?? 1.6,
      themeMode: (fields[2] as int?) ?? 0,
      dynamicColor: (fields[3] as bool?) ?? true,
      seedIndex: (fields[4] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, ReaderSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.fontSize)
      ..writeByte(1)
      ..write(obj.lineHeight)
      ..writeByte(2)
      ..write(obj.themeMode)
      ..writeByte(3)
      ..write(obj.dynamicColor)
      ..writeByte(4)
      ..write(obj.seedIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
