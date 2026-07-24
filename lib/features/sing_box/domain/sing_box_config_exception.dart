class SingBoxConfigException implements Exception {
  const SingBoxConfigException(this.message);

  final String message;

  @override
  String toString() => 'SingBoxConfigException: $message';
}
