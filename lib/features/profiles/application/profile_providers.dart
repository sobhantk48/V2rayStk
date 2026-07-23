import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';

final FutureProvider<LocalStorageService> localStorageProvider =
    FutureProvider<LocalStorageService>((Ref ref) async {
  return LocalStorageService.create();
});
