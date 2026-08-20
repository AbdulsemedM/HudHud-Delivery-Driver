import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/wallet_transfer_lookup.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_idempotency.dart';

class WalletTransferPage extends StatefulWidget {
  const WalletTransferPage({
    super.key,
    this.defaultCurrency = 'ETB',
  });

  final String defaultCurrency;

  @override
  State<WalletTransferPage> createState() => _WalletTransferPageState();
}

class _WalletTransferPageState extends State<WalletTransferPage> {
  final _identifierController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  WalletTransferLookupResult? _lookupResult;
  bool _lookupLoading = false;
  bool _nameConfirmed = false;
  bool _submitting = false;
  String? _idempotencyKey;

  @override
  void dispose() {
    _identifierController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _lookupRecipient() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) return;

    setState(() {
      _lookupLoading = true;
      _lookupResult = null;
      _nameConfirmed = false;
    });

    try {
      final result = await getIt<ApiService>().lookupWalletTransferRecipient(
        identifier,
      );
      if (!mounted) return;
      setState(() {
        _lookupResult = result;
        _lookupLoading = false;
      });
      if (result.userId == null) {
        _snack('wallet.recipient_not_found'.tr(), error: true);
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _lookupLoading = false);
      _snack(e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lookupLoading = false);
      _snack(e.toString(), error: true);
    }
  }

  Future<String> _resolveIdempotencyKey() async {
    const scope = 'wallet-transfer';
    final storage = getIt<SecureStorageService>();
    _idempotencyKey ??= await storage.getIdempotencyKey(scope);
    _idempotencyKey = PaymentIdempotency.walletTransferKey(
      existingKey: _idempotencyKey,
    );
    await storage.saveIdempotencyKey(scope, _idempotencyKey!);
    return _idempotencyKey!;
  }

  Future<void> _send() async {
    final lookup = _lookupResult;
    if (lookup?.userId == null || !_nameConfirmed) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _snack('wallet.invalid_amount'.tr(), error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final key = await _resolveIdempotencyKey();
      final res = await getIt<ApiService>().postWalletTransfer(
        recipientUserId: lookup!.userId!,
        amount: amount,
        currency: widget.defaultCurrency,
        note: _noteController.text.trim(),
        idempotencyKey: key,
      );
      if (!mounted) return;
      await getIt<SecureStorageService>().deleteIdempotencyKey('wallet-transfer');
      _snack(res['message']?.toString() ?? 'wallet.transfer_success'.tr());
      if (mounted) Navigator.pop(context, true);
    } on ConflictException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
    } on AppException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lookup = _lookupResult;
    final canSend = lookup?.userId != null && _nameConfirmed && !_submitting;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('wallet.transfer'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _identifierController,
            decoration: InputDecoration(
              labelText: 'wallet.transfer_identifier'.tr(),
              hintText: 'wallet.transfer_identifier_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _lookupLoading ? null : _lookupRecipient,
              child: _lookupLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('wallet.lookup_recipient'.tr()),
            ),
          ),
          if (lookup?.name != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'wallet.recipient_name'.tr(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lookup!.name!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (lookup.walletType != null)
                      Text(
                        lookup.walletType!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _nameConfirmed,
                      onChanged: (v) =>
                          setState(() => _nameConfirmed = v ?? false),
                      title: Text('wallet.confirm_recipient_name'.tr()),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'wallet.amount'.tr(
                namedArgs: {'currency': widget.defaultCurrency},
              ),
              border: const OutlineInputBorder(),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'wallet.transfer_note'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSend ? _send : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('wallet.send_transfer'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
