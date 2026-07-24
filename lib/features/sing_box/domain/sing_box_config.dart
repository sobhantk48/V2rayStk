import 'dart:convert';

class SingBoxConfig {
  const SingBoxConfig(this.value);

  final Map<String, dynamic> value;

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(value);
  }
}
