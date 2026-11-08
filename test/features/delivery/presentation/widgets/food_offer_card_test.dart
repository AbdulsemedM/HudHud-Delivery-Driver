import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/food_dispatch_offer.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/food_offer_card.dart';

void main() {
  late DateTime now;
  final start = DateTime(2026, 11, 6, 10, 0, 0);

  setUp(() => now = start);

  FoodDispatchOffer offer({
    int seconds = 30,
    String? currency = 'ETB',
    bool cash = false,
    bool gift = false,
    bool cooking = false,
  }) {
    return FoodDispatchOffer.fromJson({
      'offer_id': 9,
      'order_id': 41,
      'expires_in_seconds': seconds,
      'timeout_seconds': 30,
      'restaurant': {'name': 'Bole Burger', 'address': 'Bole Rd'},
      'pickup_distance_km': 0.56,
      'dropoff_area': 'Bole Atlas',
      'earnings_estimate': 33.6,
      'currency': currency,
      'is_cash': cash,
      'is_gift': gift,
      'items_count': 2,
      'waiting_for_food': cooking,
    }, receivedAt: start)!;
  }

  Widget subject(
    FoodDispatchOffer o, {
    VoidCallback? onAccept,
    VoidCallback? onDecline,
    VoidCallback? onExpired,
    bool busy = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FoodOfferCard(
          offer: o,
          text: FoodOfferCardText.english,
          busy: busy,
          clock: () => now,
          onAccept: onAccept ?? () {},
          onDecline: onDecline ?? () {},
          onExpired: onExpired,
        ),
      ),
    );
  }

  String seconds(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('food-offer-seconds'))).data!;

  testWidgets('shows restaurant, distance, drop-off area and earnings', (tester) async {
    await tester.pumpWidget(subject(offer(cash: true, cooking: true)));

    expect(find.text('New order offer'), findsOneWidget);
    expect(find.text('Bole Burger'), findsOneWidget);
    expect(find.text('Bole Rd'), findsOneWidget);
    expect(find.text('0.6 km to pickup'), findsOneWidget);
    expect(find.text('Bole Atlas'), findsOneWidget);
    expect(find.text('ETB 33.60'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.byKey(const ValueKey('food-offer-cash')), findsOneWidget);
    expect(find.byKey(const ValueKey('food-offer-gift')), findsNothing);
    expect(find.byKey(const ValueKey('food-offer-still-cooking')), findsOneWidget);
    expect(seconds(tester), '30');
  });

  testWidgets('shows USD earnings for Hargeisa orders', (tester) async {
    await tester.pumpWidget(subject(offer(currency: 'USD', gift: true)));
    expect(find.text(r'$33.60'), findsOneWidget);
    expect(find.byKey(const ValueKey('food-offer-gift')), findsOneWidget);
  });

  testWidgets('counts down every second', (tester) async {
    await tester.pumpWidget(subject(offer()));
    expect(seconds(tester), '30');

    now = start.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(seconds(tester), '29');

    now = start.add(const Duration(seconds: 21));
    await tester.pump(const Duration(seconds: 1));
    expect(seconds(tester), '9');
    final ring = tester.widget<CircularProgressIndicator>(
      find.byKey(const ValueKey('food-offer-ring')),
    );
    expect(ring.value, closeTo(9 / 30, 0.01));
  });

  testWidgets('expiry calls onExpired once and disables the buttons', (tester) async {
    var expired = 0;
    var accepted = 0;
    await tester.pumpWidget(subject(
      offer(seconds: 2),
      onExpired: () => expired += 1,
      onAccept: () => accepted += 1,
    ));
    expect(expired, 0);

    now = start.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));

    expect(expired, 1);
    expect(find.byKey(const ValueKey('food-offer-expired')), findsOneWidget);
    expect(find.text('Offer expired'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('food-offer-accept')));
    expect(accepted, 0);
    expect(
      tester.widget<ElevatedButton>(find.byKey(const ValueKey('food-offer-accept'))).onPressed,
      isNull,
    );
  });

  testWidgets('an offer that already expired notifies right away', (tester) async {
    var expired = 0;
    await tester.pumpWidget(subject(offer(seconds: 0), onExpired: () => expired += 1));
    await tester.pump();
    expect(expired, 1);
  });

  testWidgets('accept and decline call back; busy disables both', (tester) async {
    var accepted = 0;
    var declined = 0;
    await tester.pumpWidget(subject(
      offer(),
      onAccept: () => accepted += 1,
      onDecline: () => declined += 1,
    ));
    await tester.tap(find.byKey(const ValueKey('food-offer-accept')));
    await tester.tap(find.byKey(const ValueKey('food-offer-decline')));
    expect(accepted, 1);
    expect(declined, 1);

    await tester.pumpWidget(subject(
      offer(),
      busy: true,
      onAccept: () => accepted += 1,
      onDecline: () => declined += 1,
    ));
    expect(
      tester.widget<OutlinedButton>(find.byKey(const ValueKey('food-offer-decline'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<ElevatedButton>(find.byKey(const ValueKey('food-offer-accept'))).onPressed,
      isNull,
    );
  });
}
