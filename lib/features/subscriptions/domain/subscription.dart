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
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      lastUpdatedAt: json['lastUpdatedAt'] == null
          ? null
          : DateTime.parse(json['lastUpdatedAt'] as String),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
