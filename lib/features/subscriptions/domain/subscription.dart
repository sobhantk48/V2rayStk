class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    required this.lastUpdatedAt,
    required this.enabled,
  });

  final String id;
  final String name;
  final String url;
  final DateTime? lastUpdatedAt;
  final bool enabled;

  Subscription copyWith({
    String? id,
    String? name,
    String? url,
    DateTime? lastUpdatedAt,
    bool? enabled,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      'enabled': enabled,
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Subscription',
      url: json['url'] as String? ?? '',
      lastUpdatedAt: json['lastUpdatedAt'] == null
          ? null
          : DateTime.tryParse(json['lastUpdatedAt'] as String),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
