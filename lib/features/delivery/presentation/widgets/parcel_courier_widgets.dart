import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/parcel_extras.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

String _detailLabel(String key) => 'parcel.detail_$key'.tr();

String parcelSizeLabel(String? size) {
  switch (size) {
    case 'medium':
      return 'parcel.size_medium'.tr();
    case 'large':
      return 'parcel.size_large'.tr();
    case 'small':
      return 'parcel.size_small'.tr();
    default:
      return '—';
  }
}

String _errorText(Object error) => error is AppException
    ? error.message
    : error.toString().replaceFirst('Exception: ', '');

/// Item size, address details, note and "recipient pays" for v2 parcels.
class ParcelExtrasCard extends StatelessWidget {
  const ParcelExtrasCard({super.key, required this.extras});

  final ParcelExtras extras;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${parcelSizeLabel(extras.itemSize)} · ${extras.itemCategory ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (extras.recipientPays)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'parcel.recipient_pays'.tr(),
                style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
              ),
            ),
        ],
      ),
    ];
    final description = extras.itemDescription?.trim();
    if (description != null && description.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(description),
      ));
    }
    if (extras.pickupDetails.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${'parcel.pickup'.tr()}: ${parcelDetailsLine(extras.pickupDetails, _detailLabel)}',
        ),
      ));
    }
    if (extras.dropoffDetails.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${'parcel.dropoff'.tr()}: ${parcelDetailsLine(extras.dropoffDetails, _detailLabel)}',
        ),
      ));
    }
    final note = extras.courierNote?.trim();
    if (note != null && note.isNotEmpty) {
      rows.add(Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Expanded(child: Text(note)),
          ],
        ),
      ));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

/// Takes a photo with the camera and uploads it as private proof.
class ParcelProofPhotoButton extends StatefulWidget {
  const ParcelProofPhotoButton({
    super.key,
    required this.deliveryId,
    required this.kind,
    required this.count,
    this.required = false,
    this.onUploaded,
    this.light = false,
    this.stop,
  });

  final int deliveryId;

  /// Phase 11: drop-off sequence of a multi-stop parcel.
  final int? stop;

  /// pickup | delivery | return
  final String kind;
  final int count;
  final bool required;
  final ValueChanged<int>? onUploaded;

  /// White style for the orange home card.
  final bool light;

  @override
  State<ParcelProofPhotoButton> createState() => _ParcelProofPhotoButtonState();
}

class _ParcelProofPhotoButtonState extends State<ParcelProofPhotoButton> {
  bool _uploading = false;
  late int _count = widget.count;

  Future<void> _take() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 70,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final position =
          await LocationService().getCurrentPositionDetails(highAccuracy: true);
      final res = await getIt<ApiService>().uploadParcelProof(
        deliveryId: widget.deliveryId,
        file: File(picked.path),
        kind: widget.kind,
        latitude: position?['latitude'] as double?,
        longitude: position?['longitude'] as double?,
        stop: widget.stop,
      );
      final data = res['data'];
      final proofs = data is Map ? data['proofs'] : null;
      // A stop photo counts for that stop, not the parcel-wide total.
      final next = widget.stop == null &&
              proofs is Map &&
              proofs[widget.kind] is num
          ? (proofs[widget.kind] as num).toInt()
          : _count + 1;
      if (!mounted) return;
      setState(() => _count = next);
      widget.onUploaded?.call(next);
      messenger.showSnackBar(
        SnackBar(content: Text('parcel.photo_saved'.tr())),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_errorText(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.kind) {
      'pickup' => 'parcel.photo_pickup'.tr(),
      'return' => 'parcel.photo_return'.tr(),
      _ => widget.required
          ? 'parcel.photo_delivery_required'.tr()
          : 'parcel.photo_delivery'.tr(),
    };
    final done = _count > 0;
    final color = widget.light ? Colors.white : Colors.deepOrange.shade700;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _uploading ? null : _take,
        icon: _uploading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(done ? Icons.check_circle : Icons.photo_camera, color: color),
        label: Text(
          done ? '$label ($_count)' : label,
          style: TextStyle(color: color),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withAlpha(178)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Optional pickup photo on the home card; renders nothing for v1 parcels.
class ParcelPickupPhotoAction extends StatefulWidget {
  const ParcelPickupPhotoAction({super.key, required this.deliveryId});

  final int? deliveryId;

  @override
  State<ParcelPickupPhotoAction> createState() => _ParcelPickupPhotoActionState();
}

class _ParcelPickupPhotoActionState extends State<ParcelPickupPhotoAction> {
  ParcelExtras? _extras;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.deliveryId;
    if (id == null) return;
    try {
      final extras = ParcelExtras.fromResponse(
        await getIt<ApiService>().getParcelExtras(id),
      );
      if (mounted) setState(() => _extras = extras);
    } catch (_) {
      // Older backend or not a parcel: show nothing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = _extras;
    final id = widget.deliveryId;
    if (extras == null || !extras.isV2 || id == null) {
      return const SizedBox.shrink();
    }
    final cash = extras.collectAtPickup;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (cash != null && !cash.collected) ...[
            ParcelPickupCashNote(cash: cash),
            const SizedBox(height: 8),
          ],
          if (extras.isMultiStop) ...[
            Text(
              'parcel.stops_count'.tr(
                namedArgs: {'count': extras.stops.length.toString()},
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ParcelProofPhotoButton(
            deliveryId: id,
            kind: 'pickup',
            count: extras.pickupPhotos,
            light: true,
          ),
        ],
      ),
    );
  }
}

/// "Couldn't deliver" -> reason -> failed -> return to sender -> returned.
/// Returns true once the parcel is back with the sender (job closed).
Future<bool> runParcelFailFlow(BuildContext context, int deliveryId) async {
  final api = getIt<ApiService>();
  final messenger = ScaffoldMessenger.of(context);
  final reason = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'parcel.fail_title'.tr(),
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final r in kParcelFailReasons)
            ListTile(
              title: Text('parcel.fail_reason_$r'.tr()),
              onTap: () => Navigator.pop(sheetContext, r),
            ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return false;

  Map<String, dynamic> failed;
  try {
    failed = await api.failParcelDelivery(deliveryId, reason: reason);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(_errorText(e)), backgroundColor: Colors.red),
    );
    return false;
  }
  if (!context.mounted) return false;

  final returnTo = failed['return_to'];
  return runParcelReturnFlow(
    context,
    deliveryId,
    address: returnTo is Map ? returnTo['address']?.toString() : null,
    contact: returnTo is Map ? returnTo['contact_name']?.toString() : null,
  );
}

/// Bring a failed parcel (or a multi-stop parcel's failed items) back to
/// the sender. Returns true: the job is closed for the courier either way.
Future<bool> runParcelReturnFlow(
  BuildContext context,
  int deliveryId, {
  String? address,
  String? contact,
}) async {
  final api = getIt<ApiService>();
  final messenger = ScaffoldMessenger.of(context);
  final returned = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text('parcel.return_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('parcel.return_body'.tr()),
          if (address != null) ...[
            const SizedBox(height: 8),
            Text(address, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (contact != null) Text(contact),
          const SizedBox(height: 12),
          ParcelProofPhotoButton(
            deliveryId: deliveryId,
            kind: 'return',
            count: 0,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('parcel.return_later'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('parcel.return_done'.tr()),
        ),
      ],
    ),
  );
  if (returned != true) {
    messenger.showSnackBar(
      SnackBar(content: Text('parcel.return_pending'.tr())),
    );
    return true;
  }

  try {
    await api.markParcelReturned(deliveryId);
    messenger.showSnackBar(SnackBar(content: Text('parcel.returned'.tr())));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(_errorText(e)), backgroundColor: Colors.red),
    );
  }
  return true;
}

/// Phase 11: "Collect ETB 240.00 cash from the sender" before pickup.
class ParcelPickupCashNote extends StatelessWidget {
  const ParcelPickupCashNote({super.key, required this.cash});

  final ParcelPickupCash cash;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('parcel_pickup_cash_note'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: Colors.green.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'parcel.collect_at_pickup'.tr(namedArgs: {'amount': cash.label}),
              style: TextStyle(
                color: Colors.green.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks the courier to confirm the sender paid [cash]; true when confirmed.
Future<bool> confirmPickupCash(BuildContext context, ParcelPickupCash cash) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('parcel.collect_cash_title'.tr()),
      content: Text('parcel.collect_at_pickup'.tr(namedArgs: {'amount': cash.label})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('parcel.not_yet'.tr()),
        ),
        ElevatedButton(
          key: const ValueKey('parcel_pickup_cash_confirm'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('parcel.cash_received'.tr()),
        ),
      ],
    ),
  );
  return confirmed == true;
}
