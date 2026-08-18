import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/cod_preview.dart';
import 'package:hudhud_delivery_driver/core/models/driver_financial_preview.dart';

void main() {
  group('LimitStatus', () {
    test('parses API strings', () {
      expect(
        LimitStatus.fromApi('near_limit'),
        LimitStatus.nearLimit,
      );
      expect(
        LimitStatus.fromApi('blocked'),
        LimitStatus.blocked,
      );
    });

    test('blocks acceptance for overdue and blocked', () {
      expect(LimitStatus.overdue.blocksAcceptance, isTrue);
      expect(LimitStatus.blocked.blocksAcceptance, isTrue);
      expect(LimitStatus.nearLimit.blocksAcceptance, isFalse);
    });
  });

  group('accept gating', () {
    bool canAccept(DriverFinancialPreview preview) => preview.canAccept;

    test('requires all acceptance conditions', () {
      final ok = DriverFinancialPreview(
        currency: 'ETB',
        account: const DriverAccountPreview(limitStatus: LimitStatus.withinLimit),
        cod: const CodPreview(canAccept: true),
        acceptance: const AcceptancePreview(canAccept: true),
      );
      expect(canAccept(ok), isTrue);

      final blocked = DriverFinancialPreview(
        currency: 'ETB',
        account: const DriverAccountPreview(limitStatus: LimitStatus.blocked),
        cod: const CodPreview(canAccept: true),
        acceptance: const AcceptancePreview(canAccept: true),
      );
      expect(canAccept(blocked), isFalse);
    });
  });
}
