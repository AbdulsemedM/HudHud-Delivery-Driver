import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';

/// Persists the last known active package delivery id from server authority
/// (409 active_job or successful detail load) when profile pointers lag.
class ActiveDeliveryCache {
  static const _storageKey = 'cached_active_delivery';

  final FlutterSecureStorage _secureStorage;

  ActiveDeliveryCache({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  Future<void> saveFromActiveJob(ActiveJob? job) async {
    if (job?.type == ActiveJobType.delivery && job?.id != null) {
      await saveDeliveryId(job!.id!);
    }
  }

  Future<void> saveDeliveryId(int deliveryId) async {
    await _secureStorage.write(
      key: _storageKey,
      value: jsonEncode({
        'type': 'delivery',
        'id': deliveryId,
      }),
    );
  }

  Future<int?> getDeliveryId() async {
    final raw = await _secureStorage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final id = decoded['id'];
        if (id is int) return id;
        return int.tryParse(id?.toString() ?? '');
      }
      return int.tryParse(raw);
    } catch (_) {
      return int.tryParse(raw);
    }
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _storageKey);
  }
}
