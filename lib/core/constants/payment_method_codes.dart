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

  static const kAllowedPaymentMethodCodes = {
    wallet,
    cashOnDelivery,
    waafi,
    edahab,
    sahay,
    ebirr,
    ebirrKaafi,
    ebirrCoop,
  };

  /// Electronic methods for drop-off collection (no wallet, no COD).
  static const kDropOffElectronicCodes = {
    waafi,
    edahab,
    sahay,
    ebirr,
    ebirrKaafi,
    ebirrCoop,
  };

  /// Wallet funding — no wallet self-pay or COD.
  static const kWalletFundingMethodCodes = {
    waafi,
    edahab,
    sahay,
    ebirr,
    ebirrKaafi,
    ebirrCoop,
    cash,
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
}
