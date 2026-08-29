import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/branch_handoff.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/branch_handoff_card.dart';

void main() {
  const handoff = BranchHandoff(
    required: true,
    status: 'awaiting_driver_and_teller',
    otp: 'synthetic-code',
    branchName: 'Synthetic Branch',
  );

  Widget subject({
    bool isResending = false,
    bool resendLimitReached = false,
    int resendSecondsRemaining = 0,
    required VoidCallback onResend,
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.deepOrange,
        body: BranchHandoffCard(
          handoff: handoff,
          isResending: isResending,
          resendLimitReached: resendLimitReached,
          resendSecondsRemaining: resendSecondsRemaining,
          onResend: onResend,
        ),
      ),
    );
  }

  testWidgets('shows the assigned-driver resend action and invokes it once', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(subject(onResend: () => calls += 1));

    expect(find.text('Branch handoff required'), findsOneWidget);
    expect(find.text('Synthetic Branch'), findsOneWidget);
    expect(find.text('synthetic-code'), findsOneWidget);
    expect(find.text('Resend OTP SMS'), findsOneWidget);

    await tester.tap(find.text('Resend OTP SMS'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('disables resend and shows the cooldown countdown',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      subject(
        resendSecondsRemaining: 90,
        onResend: () => calls += 1,
      ),
    );

    expect(find.text('Resend in 90s'), findsOneWidget);
    final buttonFinder =
        find.byWidgetPredicate((widget) => widget is OutlinedButton);
    final button = tester.widget<OutlinedButton>(buttonFinder);
    expect(button.onPressed, isNull);
    expect(calls, 0);
  });

  testWidgets('disables resend after the server limit is reached',
      (tester) async {
    await tester.pumpWidget(
      subject(resendLimitReached: true, onResend: () {}),
    );

    expect(find.text('Resend limit reached'), findsOneWidget);
    final buttonFinder =
        find.byWidgetPredicate((widget) => widget is OutlinedButton);
    final button = tester.widget<OutlinedButton>(buttonFinder);
    expect(button.onPressed, isNull);
  });
}
