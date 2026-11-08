import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/assigned_orders_banner.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/gift_delivery_code_card.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Widget subject({
    String? errorText,
    bool locked = false,
    bool busy = false,
    required VoidCallback onSubmit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GiftDeliveryCodeCard(
          controller: controller,
          title: 'Delivery code',
          prompt: 'Ask Amina for the 4-digit code they received by SMS.',
          hint: '4-digit code',
          submitLabel: 'Confirm delivery',
          errorText: errorText,
          locked: locked,
          busy: busy,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  testWidgets('accepts at most 4 digits and submits', (tester) async {
    var calls = 0;
    await tester.pumpWidget(subject(onSubmit: () => calls += 1));

    expect(find.text('Delivery code'), findsOneWidget);
    expect(
      find.text('Ask Amina for the 4-digit code they received by SMS.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('gift-delivery-code-field')),
      '04a2789',
    );
    expect(controller.text, '0427');

    await tester.tap(find.byKey(const ValueKey('gift-delivery-code-submit')));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('shows the API error text', (tester) async {
    await tester.pumpWidget(subject(
      errorText: 'That code is not correct. 4 tries left before a 15-minute lock.',
      onSubmit: () {},
    ));
    expect(
      find.text('That code is not correct. 4 tries left before a 15-minute lock.'),
      findsOneWidget,
    );
  });

  testWidgets('locked disables entry and submit', (tester) async {
    var calls = 0;
    await tester.pumpWidget(subject(
      locked: true,
      errorText: 'Too many wrong codes.',
      onSubmit: () => calls += 1,
    ));

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('gift-delivery-code-field')),
    );
    expect(field.enabled, isFalse);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('gift-delivery-code-submit')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('gift-delivery-code-submit')));
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('assigned orders banner opens on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AssignedOrdersBanner(
          title: 'Assigned orders (1)',
          subtitle: 'Gift — deliver to Amina',
          hasGift: true,
          onTap: () => taps += 1,
        ),
      ),
    ));
    expect(find.text('Gift — deliver to Amina'), findsOneWidget);
    expect(find.byIcon(Icons.card_giftcard), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('assigned-orders-banner')));
    await tester.pump();
    expect(taps, 1);
  });
}
