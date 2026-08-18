import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/services/active_delivery_cache.dart';

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage(this._values);

  final Map<String, String> _values;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

void main() {
  group('ActiveDeliveryCache', () {
    late Map<String, String> storage;
    late ActiveDeliveryCache cache;

    setUp(() {
      storage = {};
      cache = ActiveDeliveryCache(secureStorage: _FakeSecureStorage(storage));
    });

    test('saveFromActiveJob stores delivery id only', () async {
      await cache.saveFromActiveJob(
        ActiveJob(type: ActiveJobType.delivery, id: 95),
      );
      expect(await cache.getDeliveryId(), 95);

      await cache.saveFromActiveJob(
        ActiveJob(type: ActiveJobType.ride, id: 12),
      );
      expect(await cache.getDeliveryId(), 95);
    });

    test('clear removes cached delivery id', () async {
      await cache.saveDeliveryId(44);
      await cache.clear();
      expect(await cache.getDeliveryId(), isNull);
    });
  });

  group('ActiveJob.resolveDeliveryIdForHome', () {
    test('prefers profile current_delivery_id over cache', () {
      expect(
        ActiveJob.resolveDeliveryIdForHome(
          profile: {
            'driver_profile': {'current_delivery_id': 10},
          },
          cachedDeliveryId: 99,
        ),
        10,
      );
    });

    test('falls back to cached id when profile pointer is missing', () {
      expect(
        ActiveJob.resolveDeliveryIdForHome(
          profile: {'driver_profile': {}},
          cachedDeliveryId: 99,
        ),
        99,
      );
    });

    test('offline restore uses initial id then cache when profile unavailable', () {
      expect(
        ActiveJob.resolveDeliveryIdForHome(
          initialDeliveryId: 77,
          cachedDeliveryId: 99,
        ),
        77,
      );
      expect(
        ActiveJob.resolveDeliveryIdForHome(cachedDeliveryId: 99),
        99,
      );
    });

    test('reads current_job delivery pointer when added by backend', () {
      expect(
        ActiveJob.deliveryIdFromProfile({
          'driver_profile': {
            'current_job': {'type': 'delivery', 'id': 55},
          },
        }),
        55,
      );
    });
  });
}
