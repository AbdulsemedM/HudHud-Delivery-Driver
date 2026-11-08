import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/parcel_extras.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/parcel_stops_flow.dart';

ParcelExtras _extras(String status, List<String> stopStatuses) =>
    ParcelExtras.fromResponse({
      'success': true,
      'data': {
        'id': 7,
        'version': 2,
        'status': status,
        'stops': [
          for (var i = 0; i < stopStatuses.length; i++)
            {'sequence': i + 1, 'status': stopStatuses[i]},
        ],
      },
    })!;

void main() {
  test('PARCEL_STOP_CLOSED after a lost response is treated as done', () {
    final error = ConflictException(
      'This stop is already delivered.',
      code: 'PARCEL_STOP_CLOSED',
      details: {'code': 'PARCEL_STOP_CLOSED', 'stop_status': 'delivered'},
    );
    final result = ParcelStopRetry.resolvedResult(
      error,
      _extras('in_transit', ['delivered', 'pending']),
    );
    expect(result, isNotNull);
    expect(result!['all_stops_resolved'], isFalse);
  });

  test('last stop already closed the parcel', () {
    final error = ConflictException(
      'Confirm pickup before serving the drop-offs.',
      code: 'PARCEL_NOT_PICKED_UP',
      details: {'code': 'PARCEL_NOT_PICKED_UP', 'status': 'delivered'},
    );
    final result = ParcelStopRetry.resolvedResult(
      error,
      _extras('delivered', ['delivered', 'delivered']),
    );
    expect(result!['all_stops_resolved'], isTrue);
    expect(result['parcel_status'], 'delivered');
  });

  test('a failed parcel goes to the return flow', () {
    final error = ConflictException('x', details: {'code': 'PARCEL_NOT_PICKED_UP'});
    final result = ParcelStopRetry.resolvedResult(
      error,
      _extras('failed', ['failed', 'failed']),
    );
    expect(result!['parcel_status'], 'failed');
  });

  test('real errors still surface', () {
    expect(
      ParcelStopRetry.resolvedResult(
        BadRequestException('x', details: {'code': 'DELIVERY_PHOTO_REQUIRED'}),
        _extras('in_transit', ['arrived']),
      ),
      isNull,
    );
    // Not picked up yet (parcel still open) is a real error.
    expect(
      ParcelStopRetry.resolvedResult(
        ConflictException('x', details: {'code': 'PARCEL_NOT_PICKED_UP'}),
        _extras('accepted', ['pending']),
      ),
      isNull,
    );
  });
}
