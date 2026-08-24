/// Payment method codes aligned with the HudHud customer payment client.
class PaymentMethodCodes {
  PaymentMethodCodes._();

  static const wallet = 'wallet';
  static const cashOnDelivery = 'cash_on_delivery';
  static const cash = 'cash';
  static const waafi = 'waafi';
  static const edahab = 'edahab';
  static const sahay = 'sahay';
  static const ebirr = 'ebirr';
  static const ebirrKaafi = 'ebirr_kaafi';
  static const ebirrCoop = 'ebirr_coop';
  static const qpay = 'qpay';

  static const qpayNotConfigured = 'QPAY_NOT_CONFIGURED';
  static const qpayQrGenerationFailed = 'QPAY_QR_GENERATION_FAILED';
  static const qpayQrGenerationUnavailable = 'QPAY_QR_GENERATION_UNAVAILABLE';
  static const qpayStatusUnavailable = 'QPAY_STATUS_UNAVAILABLE';
  static const qpayTransactionReferenceMissing =
      'QPAY_TRANSACTION_REFERENCE_MISSING';

  static const kAllowedPaymentMethodCodes = {
    wallet,
    cashOnDelivery,
    waafi,
    edahab,
    sahay,
    ebirr,
    ebirrKaafi,
    ebirrCoop,
    qpay,
  };

  /// Electronic methods for drop-off collection (no wallet, no COD).
  static const kDropOffElectronicCodes = {
    qpay,
    ebirrCoop,
    ebirrKaafi,
    sahay,
    ebirr,
    waafi,
    edahab,
  };

  static const dropOffDisplayOrder = [
    qpay,
    ebirrCoop,
    ebirrKaafi,
    sahay,
  ];

  static int dropOffDisplayRank(String code) {
    final index = dropOffDisplayOrder.indexOf(code);
    if (index >= 0) return index;
    return dropOffDisplayOrder.length + (code == ebirr ? 0 : 1);
  }

  static int compareDropOffDisplay(String a, String b) {
    final cmp = dropOffDisplayRank(a).compareTo(dropOffDisplayRank(b));
    if (cmp != 0) return cmp;
    return a.compareTo(b);
  }

  static List<T> sortDropOffMethods<T>(
    List<T> methods, {
    required String Function(T item) codeOf,
  }) {
    final copy = List<T>.from(methods);
    copy.sort((a, b) => compareDropOffDisplay(codeOf(a), codeOf(b)));
    return copy;
  }

  /// Wallet funding — no wallet self-pay or COD.
  static const kWalletFundingMethodCodes = {
    waafi,
    edahab,
    sahay,
    ebirr,
    ebirrKaafi,
    ebirrCoop,
    cash,
    qpay,
  };

  static bool requiresPhone(String code) {
    return code == waafi ||
        code == edahab ||
        code == sahay ||
        code == ebirr ||
        code == ebirrKaafi ||
        code == ebirrCoop;
  }

  static bool isEbirrLegacy(String code) => code == ebirr;

  static bool isEbirrFamily(String code) =>
      code == ebirr || code == ebirrKaafi || code == ebirrCoop;

  static bool isQpay(String code) => code == qpay;

  /// Drop-off collect-payment `collection_method`: cash, qpay, or ebirr.
  /// Kaafi vs Coop is distinguished by [ebirrProvider] in payment_details.
  static String collectionMethodFor(String code) {
    if (code == cash) return cash;
    if (code == qpay) return qpay;
    if (isEbirrFamily(code)) return ebirr;
    return code;
  }

  /// eBirr USSD provider: Coop vs Kaafi.
  static String? ebirrProvider(String code) {
    if (code == ebirrCoop) return 'coop';
    if (code == ebirrKaafi || code == ebirr) return 'kaafi';
    return null;
  }
}
