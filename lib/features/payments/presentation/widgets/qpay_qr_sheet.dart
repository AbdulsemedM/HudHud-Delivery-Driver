import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/collection_payment_result.dart';
import 'package:hudhud_delivery_driver/core/models/payment_initiate_result.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/collection_poller.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_poller.dart';
import 'package:hudhud_delivery_driver/core/utils/qpay_qr_payload.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum QPayState {
  idle,
  initiating,
  awaitingScan,
  polling,
  completed,
  failed,
  expired,
  unavailable,
}

enum QPayFlowContext { walletTopUp, deliveryCollection }

enum QPayQrSheetResult { completed, failed, expired, unavailable, dismissed }

Future<QPayQrSheetResult?> showQPayQrSheet({
  required BuildContext context,
  required String qrCode,
  required QPayFlowContext flowContext,
  double? amount,
  String? currency,
  DateTime? expiresAt,
  int? paymentId,
  int? deliveryId,
  String? deliveryReference,
}) {
  assert(
    paymentId != null || deliveryId != null,
    'Provide paymentId (wallet) or deliveryId (driver collection).',
  );
  return showModalBottomSheet<QPayQrSheetResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => QPayQrSheet(
      flowContext: flowContext,
      paymentId: paymentId,
      deliveryId: deliveryId,
      qrCode: qrCode,
      amount: amount,
      currency: currency,
      expiresAt: expiresAt,
      deliveryReference: deliveryReference,
    ),
  );
}

class QPayQrSheet extends StatefulWidget {
  const QPayQrSheet({
    super.key,
    required this.flowContext,
    this.paymentId,
    this.deliveryId,
    required this.qrCode,
    this.amount,
    this.currency,
    this.expiresAt,
    this.deliveryReference,
  }) : assert(
          paymentId != null || deliveryId != null,
          'Provide paymentId or deliveryId',
        );

  final QPayFlowContext flowContext;
  final int? paymentId;
  final int? deliveryId;
  final String qrCode;
  final double? amount;
  final String? currency;
  final DateTime? expiresAt;
  final String? deliveryReference;

  @override
  State<QPayQrSheet> createState() => _QPayQrSheetState();
}

class _QPayQrSheetState extends State<QPayQrSheet>
    with WidgetsBindingObserver {
  late final QPayQrPayload _payload;
  PaymentPoller? _paymentPoller;
  CollectionPoller? _collectionPoller;
  QPayState _state = QPayState.awaitingScan;
  bool _pollingPaused = false;

  bool get _isDelivery =>
      widget.flowContext == QPayFlowContext.deliveryCollection;

  @override
  void initState() {
    super.initState();
    _payload = QPayQrPayload.parse(widget.qrCode);
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentPoller?.stop();
    _collectionPoller?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pausePolling();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _resumePolling();
    }
  }

  void _pausePolling() {
    if (_pollingPaused) return;
    _pollingPaused = true;
    _paymentPoller?.stop();
    _collectionPoller?.stop();
  }

  void _resumePolling() {
    if (!_pollingPaused) return;
    _pollingPaused = false;
    _startPolling();
  }

  void _startPolling() {
    if (_pollingPaused) return;
    _paymentPoller?.stop();
    _collectionPoller?.stop();
    if (!mounted) return;
    setState(() => _state = QPayState.polling);

    if (widget.deliveryId != null) {
      _collectionPoller = CollectionPoller(api: getIt<ApiService>());
      _collectionPoller!.start(
        deliveryId: widget.deliveryId!,
        onUpdate: _handleCollectionUpdate,
        onFatal: (_) {
          if (!mounted) return;
          setState(() => _state = QPayState.unavailable);
          Navigator.of(context).pop(QPayQrSheetResult.unavailable);
        },
      );
      return;
    }

    _paymentPoller = PaymentPoller(api: getIt<ApiService>());
    _paymentPoller!.startWalletTopUp(
      paymentId: widget.paymentId!,
      onUpdate: (status) {
        if (!mounted) return;
        if (status.isCompleted) {
          setState(() => _state = QPayState.completed);
          Navigator.of(context).pop(QPayQrSheetResult.completed);
          return;
        }
        if (status.isExpired) {
          setState(() => _state = QPayState.expired);
          Navigator.of(context).pop(QPayQrSheetResult.expired);
          return;
        }
        if (status.isTerminalFailure) {
          setState(() => _state = QPayState.failed);
          Navigator.of(context).pop(QPayQrSheetResult.failed);
        }
      },
      onFatal: (_) {
        if (!mounted) return;
        setState(() => _state = QPayState.unavailable);
        Navigator.of(context).pop(QPayQrSheetResult.unavailable);
      },
    );
  }

  void _handleCollectionUpdate(CollectionPaymentResult status) {
    if (!mounted) return;
    if (status.isCollectionComplete || status.isSettled) {
      setState(() => _state = QPayState.completed);
      Navigator.of(context).pop(QPayQrSheetResult.completed);
      return;
    }
    if (status.isTerminalFailure) {
      final expired = status.qpayStatus?.toUpperCase() == 'EXPIRED' ||
          status.status?.toLowerCase() ==
              CollectionPaymentResult.statusExpired;
      setState(
        () => _state = expired ? QPayState.expired : QPayState.failed,
      );
      Navigator.of(context).pop(
        expired ? QPayQrSheetResult.expired : QPayQrSheetResult.failed,
      );
    }
  }

  String get _titleKey =>
      _isDelivery ? 'wallet.qpay_delivery_title' : 'wallet.qpay_title';

  String get _keepOpenKey => _isDelivery
      ? 'wallet.qpay_delivery_keep_open'
      : 'wallet.qpay_keep_open';

  String get _typeLabelKey => _isDelivery
      ? 'wallet.qpay_delivery_type'
      : 'wallet.qpay_wallet_type';

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;
    final amountLabel = widget.amount != null
        ? AppCurrency.format(
            widget.amount!,
            currency: widget.currency ?? 'ETB',
          )
        : null;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _titleKey.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'wallet.qpay_pending_badge'.tr(),
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _typeLabelKey.tr(),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (amountLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  amountLabel,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_isDelivery && widget.deliveryReference != null) ...[
                const SizedBox(height: 4),
                Text(
                  'wallet.qpay_delivery_reference'.tr(
                    namedArgs: {'ref': widget.deliveryReference!},
                  ),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _keepOpenKey.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              if (!_isDelivery) ...[
                const SizedBox(height: 6),
                Text(
                  'wallet.qpay_banks_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (widget.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'wallet.qpay_expires'.tr(
                    namedArgs: {
                      'time': DateFormat.Hm().format(
                        widget.expiresAt!.toLocal(),
                      ),
                    },
                  ),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(child: Center(child: _buildQr())),
              const SizedBox(height: 12),
              if (_state == QPayState.polling ||
                  _state == QPayState.awaitingScan)
                Text(
                  'wallet.qpay_waiting'.tr(),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(QPayQrSheetResult.dismissed),
                child: Text('common.back'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQr() {
    switch (_payload.kind) {
      case QPayQrKind.imageBytes:
        return Image.memory(_payload.bytes!, fit: BoxFit.contain);
      case QPayQrKind.imageUrl:
        return Image.network(_payload.url!, fit: BoxFit.contain);
      case QPayQrKind.qrValue:
        return QrImageView(
          data: _payload.value ?? '',
          version: QrVersions.auto,
          size: 240,
        );
    }
  }
}

bool qpayInitiateLooksValid(PaymentInitiateResult result) {
  return result.isSuccess &&
      result.nextAction == PaymentInitiateResult.nextActionShowQr &&
      result.paymentId != null &&
      result.qrCode != null &&
      result.qrCode!.isNotEmpty;
}
