import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/food_offer_coordinator.dart';

void main() {
  test('offers never open over splash, login or account gates', () {
    for (final path in [
      AppRouter.splashPath,
      AppRouter.loginPath,
      AppRouter.applicationPendingPath,
      AppRouter.applicationSuspendedPath,
      AppRouter.forceUpdatePath,
      null,
      '',
    ]) {
      expect(FoodOfferCoordinator.isOfferBlockedPath(path), isTrue,
          reason: '$path');
    }
  });

  test('offers open on the work screens', () {
    for (final path in [
      AppRouter.deliveryHomePath,
      AppRouter.rideHomePath,
      AppRouter.deliveryWalletPath,
      AppRouter.availableDeliveriesPath,
    ]) {
      expect(FoodOfferCoordinator.isOfferBlockedPath(path), isFalse,
          reason: path);
    }
  });
}
