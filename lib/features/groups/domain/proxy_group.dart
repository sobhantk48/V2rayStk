class ProxyGroup {
  const ProxyGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    this.colorValue,
    this.sortOrder = 0,
    this.isCollapsed = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// رنگ برچسب گروه در UI (ARGB). null یعنی رنگ پیش‌فرض تم.
  final int? colorValue;

  final int sortOrder;
  final bool isCollapsed;

  ProxyGroup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? colorValue,
    int? sortOrder,
    bool? isCollapsed,
    bool clearColor = false,
  }) {
    return ProxyGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      sortOrder: sortOrder ?? this.sortOrder,
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'colorValue': colorValue,
      'sortOrder': sortOrder,
      'isCollapsed': isCollapsed,
    };
  }

  factory ProxyGroup.fromJson(Map<String, dynamic> json) {
    return ProxyGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Group',
      createdAt: json['createdAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(json['createdAt'] as String),
      colorValue: json['colorValue'] as int?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isCollapsed: json['isCollapsed'] as bool? ?? false,
    );
  }
}
