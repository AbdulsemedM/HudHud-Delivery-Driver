import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/parcel_extras.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/parcel_courier_widgets.dart';
import 'package:hudhud_delivery_driver/core/utils/driver_error_messages.dart';

String _errorText(Object error) => DriverErrorMessages.message(error);

String parcelStopStatusLabel(String status) {
  switch (status) {
    case 'arrived':
      return 'parcel.stop_status_arrived'.tr();
    case 'delivered':
      return 'parcel.stop_status_delivered'.tr();
    case 'failed':
      return 'parcel.stop_status_failed'.tr();
    case 'returned':
      return 'parcel.stop_status_returned'.tr();
    default:
      return 'parcel.stop_status_pending'.tr();
  }
}

/// Phase 11 multi-stop parcel: the drop-offs in order. The courier serves
/// the current stop only: arrive -> recipient's code -> photo (if required)
/// -> complete, or "couldn't deliver". The parcel closes itself after the
/// last stop; failed stops are brought back to the sender at the end.
///
/// [onFinished] is called once the job is closed for the courier.
class ParcelStopsFlow extends StatefulWidget {
  const ParcelStopsFlow({
    super.key,
    required this.deliveryId,
    required this.initial,
    required this.onFinished,
  });

  final int deliveryId;
  final ParcelExtras initial;
  final VoidCallback onFinished;

  @override
  State<ParcelStopsFlow> createState() => _ParcelStopsFlowState();
}

class _ParcelStopsFlowState extends State<ParcelStopsFlow> {
  late ParcelExtras _extras = widget.initial;
  final _code = TextEditingController();
  bool _busy = false;

  ApiService get _api => getIt<ApiService>();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final next = ParcelExtras.fromResponse(
        await _api.getParcelExtras(widget.deliveryId),
      );
      if (mounted && next != null) setState(() => _extras = next);
    } catch (_) {
      // Keep the last state; the next action reloads again.
    }
  }

  /// Runs a stop action; returns the response or null after showing the error.
  Future<Map<String, dynamic>?> _run(
    int sequence,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final res = await _api.parcelStopAction(
        widget.deliveryId,
        sequence,
        action,
        body: body,
      );
      await _reload();
      return res;
    } catch (e) {
      await _reload();
      // A retry after a lost response: the stop (or the whole parcel) was
      // already resolved server side, so carry on instead of showing an error.
      final done = ParcelStopRetry.resolvedResult(e, _extras);
      if (done != null) return done;
      messenger.showSnackBar(
        SnackBar(content: Text(_errorText(e)), backgroundColor: Colors.red),
      );
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(ParcelCourierStop stop) async {
    final code = _code.text.trim();
    if (code.length != stop.handoverDigits) return;
    final res = await _run(stop.sequence, 'handover', body: {'code': code});
    if (res != null) _code.clear();
  }

  Future<void> _complete(ParcelCourierStop stop) async {
    final position =
        await LocationService().getCurrentPositionDetails(highAccuracy: true);
    final res = await _run(stop.sequence, 'complete', body: {
      if (position?['latitude'] != null) 'latitude': position!['latitude'],
      if (position?['longitude'] != null) 'longitude': position!['longitude'],
    });
    if (res != null) await _afterResolved(res);
  }

  Future<void> _fail(ParcelCourierStop stop) async {
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
    if (reason == null || !mounted) return;
    final res = await _run(stop.sequence, 'fail', body: {'reason': reason});
    if (res != null) await _afterResolved(res);
  }

  Future<void> _afterResolved(Map<String, dynamic> res) async {
    if (res['all_stops_resolved'] != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (res['parcel_status'] == 'failed') {
      await runParcelReturnFlow(context, widget.deliveryId);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('parcel.stops_all_delivered'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    }
    if (mounted) widget.onFinished();
  }

  Future<void> _navigate(ParcelCourierStop stop) async {
    final lat = stop.latitude;
    final lng = stop.longitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  @override
  Widget build(BuildContext context) {
    final current = _extras.current;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'parcel.stops_title'.tr(
            namedArgs: {'count': _extras.stops.length.toString()},
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'parcel.stops_in_order'.tr(),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        for (final stop in _extras.stops)
          _StopCard(
            key: ValueKey('parcel_stop_${stop.sequence}'),
            stop: stop,
            current: current?.sequence == stop.sequence,
            busy: _busy,
            photoRequired: _extras.deliveryPhotoRequired,
            deliveryId: widget.deliveryId,
            code: _code,
            onArrive: () => _run(stop.sequence, 'arrive'),
            onVerify: () => _verify(stop),
            onComplete: () => _complete(stop),
            onFail: () => _fail(stop),
            onNavigate: () => _navigate(stop),
            onCall: stop.recipientPhone == null
                ? null
                : () => _call(stop.recipientPhone!),
            onPhoto: (_) => _reload(),
          ),
      ],
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    super.key,
    required this.stop,
    required this.current,
    required this.busy,
    required this.photoRequired,
    required this.deliveryId,
    required this.code,
    required this.onArrive,
    required this.onVerify,
    required this.onComplete,
    required this.onFail,
    required this.onNavigate,
    required this.onPhoto,
    this.onCall,
  });

  final ParcelCourierStop stop;
  final bool current;
  final bool busy;
  final bool photoRequired;
  final int deliveryId;
  final TextEditingController code;
  final VoidCallback onArrive;
  final VoidCallback onVerify;
  final VoidCallback onComplete;
  final VoidCallback onFail;
  final VoidCallback onNavigate;
  final VoidCallback? onCall;
  final ValueChanged<int> onPhoto;

  @override
  Widget build(BuildContext context) {
    final photoMissing = photoRequired && stop.deliveryPhotos == 0;
    final details = parcelDetailsLine(
      stop.details,
      (key) => 'parcel.detail_$key'.tr(),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: current ? Colors.deepOrange.shade400 : Colors.grey.shade300,
          width: current ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'parcel.stop_n'.tr(
                    namedArgs: {'number': stop.sequence.toString()},
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                parcelStopStatusLabel(stop.status),
                style: TextStyle(
                  color: stop.status == 'failed'
                      ? Colors.red.shade700
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          if (stop.address != null) ...[
            const SizedBox(height: 4),
            Text(stop.address!),
          ],
          if (details.isNotEmpty)
            Text(details, style: TextStyle(color: Colors.grey.shade700)),
          if (stop.recipientName != null || stop.recipientPhone != null)
            Text(
              [stop.recipientName, stop.recipientPhone]
                  .whereType<String>()
                  .join(' · '),
              style: TextStyle(color: Colors.grey.shade800),
            ),
          if (stop.note != null && stop.note!.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(stop.note!),
            ),
          if (current) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_outlined),
                    label: Text('parcel.navigate'.tr()),
                  ),
                ),
                if (onCall != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.call_outlined),
                      label: Text('parcel.call_recipient'.tr()),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (!stop.arrived && !stop.handoverVerified)
              ElevatedButton(
                key: ValueKey('parcel_stop_${stop.sequence}_arrive'),
                onPressed: busy ? null : onArrive,
                child: Text('parcel.stop_arrived'.tr()),
              )
            else if (!stop.handoverVerified) ...[
              if (stop.handoverLocked)
                Text(
                  'parcel.stop_code_locked'.tr(),
                  style: TextStyle(color: Colors.red.shade700),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('parcel_stop_${stop.sequence}_code'),
                        controller: code,
                        keyboardType: TextInputType.number,
                        maxLength: stop.handoverDigits,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'parcel.stop_code_label'.tr(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      key: ValueKey('parcel_stop_${stop.sequence}_verify'),
                      onPressed: busy ? null : onVerify,
                      child: Text('parcel.stop_verify'.tr()),
                    ),
                  ],
                ),
            ] else ...[
              ParcelProofPhotoButton(
                key: ValueKey('parcel_stop_${stop.sequence}_photo'),
                deliveryId: deliveryId,
                kind: 'delivery',
                count: stop.deliveryPhotos,
                required: photoRequired,
                stop: stop.sequence,
                onUploaded: onPhoto,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                key: ValueKey('parcel_stop_${stop.sequence}_complete'),
                onPressed: busy || photoMissing ? null : onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('parcel.stop_complete'.tr()),
              ),
            ],
            TextButton(
              key: ValueKey('parcel_stop_${stop.sequence}_fail'),
              onPressed: busy ? null : onFail,
              child: Text(
                'parcel.could_not_deliver'.tr(),
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Makes multi-stop actions safe to repeat after a lost response (the API
/// answers PARCEL_STOP_CLOSED for a stop that is already delivered / failed,
/// and PARCEL_NOT_PICKED_UP once the last stop closed the parcel).
class ParcelStopRetry {
  ParcelStopRetry._();

  static const Set<String> terminalParcelStatuses = {
    'delivered',
    'completed',
    'failed',
    'returned',
    'cancelled',
  };

  /// A synthetic action result (`all_stops_resolved`, `parcel_status`) when
  /// [error] only means "already done", given the freshly reloaded [extras];
  /// null for a real error.
  static Map<String, dynamic>? resolvedResult(
    Object error,
    ParcelExtras extras,
  ) {
    final code = DriverErrorMessages.codeOf(error);
    final parcelStatus = extras.status?.toLowerCase();
    final parcelClosed =
        parcelStatus != null && terminalParcelStatuses.contains(parcelStatus);
    final stopClosed = code == DriverErrorMessages.parcelStopClosed;
    final closedByLastStop =
        code == DriverErrorMessages.parcelNotPickedUp && parcelClosed;
    if (!stopClosed && !closedByLastStop) return null;
    final allResolved =
        parcelClosed || extras.stops.every((stop) => stop.isResolved);
    return <String, dynamic>{
      'success': true,
      'idempotent': true,
      'all_stops_resolved': allResolved,
      if (parcelStatus != null) 'parcel_status': parcelStatus,
    };
  }
}
