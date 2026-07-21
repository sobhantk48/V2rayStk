import 'package:hive/hive.dart';

part 'profile.g.dart';

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
