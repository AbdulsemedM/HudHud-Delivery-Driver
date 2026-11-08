import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/available_food_orders_page.dart';

void main() {
  test('rows leave the list when the order is gone or not ours to take', () {
    expect(
      AvailableFoodOrdersPage.removesRow(ConflictException(
        'HudHud assigns this order.',
        code: 'DISPATCH_OFFER_REQUIRED',
        details: {'code': 'DISPATCH_OFFER_REQUIRED'},
      )),
      isTrue,
    );
    expect(
      AvailableFoodOrdersPage.removesRow(ForbiddenException(
        'Other city',
        code: 'DRIVER_CITY_MISMATCH',
        details: {'code': 'DRIVER_CITY_MISMATCH'},
      )),
      isTrue,
    );
    expect(
      AvailableFoodOrdersPage.removesRow(ConflictException(
        'This order is no longer available.',
        details: {'reason': 'unavailable'},
      )),
      isTrue,
    );
  });

  test('rows stay for errors the rider can fix', () {
    expect(
      AvailableFoodOrdersPage.removesRow(ConflictException(
        'Low balance',
        code: 'LOW_WALLET_BALANCE',
        details: {'code': 'LOW_WALLET_BALANCE'},
      )),
      isFalse,
    );
    expect(
      AvailableFoodOrdersPage.removesRow(BadRequestException(
        'Invalid pickup OTP',
        code: 'INVALID_PICKUP_OTP',
        details: {'code': 'INVALID_PICKUP_OTP'},
      )),
      isFalse,
    );
    expect(
      AvailableFoodOrdersPage.removesRow(ConflictException(
        'Finish your job',
        code: 'DRIVER_ACTIVE_JOB_CONFLICT',
        details: {'code': 'DRIVER_ACTIVE_JOB_CONFLICT'},
      )),
      isFalse,
    );
    expect(AvailableFoodOrdersPage.removesRow(NetworkException('x')), isFalse);
  });
}
