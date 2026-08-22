import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/collection_payment_result.dart';
import 'package:hudhud_delivery_driver/core/models/payment_initiate_result.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
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

enum QPayQrSheetResult { completed, failed, expired, unavailable, dismissed }

Future<QPayQrSheetResult?> showQPayQrSheet({
  required BuildContext context,
  required String qrCode,
  DateTime? expiresAt,
  int? paymentId,
  int? deliveryId,
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
      paymentId: paymentId,
      deliveryId: deliveryId,
      qrCode: qrCode,
      expiresAt: expiresAt,
    ),
  );
}

class QPayQrSheet extends StatefulWidget {
  const QPayQrSheet({
    super.key,
    this.paymentId,
    this.deliveryId,
    required this.qrCode,
    this.expiresAt,
  }) : assert(
          paymentId != null || deliveryId != null,
          'Provide paymentId or deliveryId',
        );

  final int? paymentId;
  final int? deliveryId;
  final String qrCode;
  final DateTime? expiresAt;

  @override
  State<QPayQrSheet> createState() => _QPayQrSheetState();
}

class _QPayQrSheetState extends State<QPayQrSheet>
    with WidgetsBindingObserver {
  late final QPayQrPayload _payload;
  PaymentPoller? _paymentPoller;
  CollectionPoller? _collectionPoller;
  QPayState _state = QPayState.awaitingScan;

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
    if (state == AppLifecycleState.resumed) {
      _paymentPoller?.pollOnce();
      _collectionPoller?.pollOnce();
    }
  }

  void _startPolling() {
    _paymentPoller?.stop();
    _collectionPoller?.stop();
    setState(() => _state = QPayState.polling);

    if (widget.deliveryId != null) {
      _collectionPoller = CollectionPoller(api: getIt<ApiService>());
      _collectionPoller!.start(
        deliveryId: widget.deliveryId!,
        onUpdate: _handleCollectionUpdate,
      );
      return;
    }

    _paymentPoller = PaymentPoller(api: getIt<ApiService>());
    _paymentPoller!.start(
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
    if (status.isSettled ||
        status.nextAction ==
            CollectionPaymentResult.nextActionCompleteDelivery) {
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

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;
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
                'wallet.qpay_title'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'wallet.qpay_keep_open'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
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
