// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleTimeAdapter extends TypeAdapter<ScheduleTime> {
  @override
  final int typeId = 4;

  @override
  ScheduleTime read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduleTime(
      hour: fields[0] as int,
      minute: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleTime obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.hour)
      ..writeByte(1)
      ..write(obj.minute);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleTimeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScheduleAdapter extends TypeAdapter<Schedule> {
  @override
  final int typeId = 1;

  @override
  Schedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Schedule(
      times: (fields[0] as List).cast<ScheduleTime>(),
      repeatDays: (fields[1] as List).cast<int>(),
      intervalWeeks: fields[2] == null ? 1 : fields[2] as int,
    )..anchorDateMillis = fields[3] == null ? 0 : fields[3] as int;
  }

  @override
  void write(BinaryWriter writer, Schedule obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.times)
      ..writeByte(1)
      ..write(obj.repeatDays)
      ..writeByte(2)
      ..write(obj.intervalWeeks)
      ..writeByte(3)
      ..write(obj.anchorDateMillis);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
