import 'profile_type.dart';

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.server,
    required this.port,
    required this.type,
    required this.rawConfig,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String server;
  final int port;
  final ProfileType type;
  final String rawConfig;
  final bool isActive;
  final DateTime createdAt;

  Profile copyWith({
    String? id,
    String? name,
    String? server,
    int? port,
    ProfileType? type,
    String? rawConfig,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      server: server ?? this.server,
      port: port ?? this.port,
      type: type ?? this.type,
      rawConfig: rawConfig ?? this.rawConfig,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'server': server,
      'port': port,
      'type': profileTypeToJson(type),
      'rawConfig': rawConfig,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed',
      server: json['server'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      type: parseProfileType(json['type'] as String? ?? ''),
      rawConfig: json['rawConfig'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
