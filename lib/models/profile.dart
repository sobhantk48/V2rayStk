import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class Profile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String config;

  @HiveField(3)
  String? remark;

  @HiveField(4)
  bool isSelected;

  @HiveField(5)
  DateTime createdAt;

  Profile({
    required this.id,
    required this.name,
    required this.config,
    this.remark,
    this.isSelected = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Profile copyWith({
    String? id,
    String? name,
    String? config,
    String? remark,
    bool? isSelected,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      config: config ?? this.config,
      remark: remark ?? this.remark,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProfileAdapter extends TypeAdapter<Profile> {
  @override
  final int typeId = 0;

  @override
  Profile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Profile(
      id: fields[0] as String,
      name: fields[1] as String,
      config: fields[2] as String,
      remark: fields[3] as String?,
      isSelected: fields[4] as bool? ?? false,
      createdAt: fields[5] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Profile obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.config)
      ..writeByte(3)
      ..write(obj.remark)
      ..writeByte(4)
      ..write(obj.isSelected)
      ..writeByte(5)
      ..write(obj.createdAt);
  }
}
