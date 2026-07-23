class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.type,
    required this.rawConfig,
    this.server,
    this.port,
    this.isActive = false,
  });

  final String id;
  final String name;
  final String type;
  final String rawConfig;
  final String? server;
  final int? port;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'rawConfig': rawConfig,
      'server': server,
      'port': port,
      'isActive': isActive,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      rawConfig: json['rawConfig'] as String,
      server: json['server'] as String?,
      port: json['port'] as int?,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
