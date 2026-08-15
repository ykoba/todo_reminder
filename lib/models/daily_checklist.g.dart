// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_checklist.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyChecklistAdapter extends TypeAdapter<DailyChecklist> {
  @override
  final int typeId = 3;

  @override
  DailyChecklist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyChecklist(
      id: fields[0] as String,
      todoSetId: fields[1] as String,
      dateKey: fields[2] as String,
      checkedItemIds: (fields[3] as List).cast<String>(),
      completedAt: fields[4] as DateTime?,
      memo: fields[5] == null ? '' : fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DailyChecklist obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.todoSetId)
      ..writeByte(2)
      ..write(obj.dateKey)
      ..writeByte(3)
      ..write(obj.checkedItemIds)
      ..writeByte(4)
      ..write(obj.completedAt)
      ..writeByte(5)
      ..write(obj.memo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyChecklistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
