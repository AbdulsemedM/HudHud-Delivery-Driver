import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds map marker icons from assets at a map-friendly size.
class MapMarkerIcons {
  MapMarkerIcons._();

  static const deliveryGuyAsset = 'assets/images/delivery-guy.png';

  /// On-map width in logical pixels (source PNG is 2500×2500).
  static const double deliveryGuyLogicalWidth = 56;

  static BitmapDescriptor? _deliveryGuy;
  static Future<BitmapDescriptor>? _deliveryGuyLoading;

  /// Cached delivery-guy pin, scaled down from the large source PNG.
  static Future<BitmapDescriptor> deliveryGuy({
    double devicePixelRatio = 2.0,
  }) {
    if (_deliveryGuy != null) {
      return Future.value(_deliveryGuy!);
    }
    return _deliveryGuyLoading ??= _loadDeliveryGuy(devicePixelRatio);
  }

  static Future<BitmapDescriptor> _loadDeliveryGuy(double dpr) async {
    final icon = await fromAsset(
      deliveryGuyAsset,
      logicalWidth: deliveryGuyLogicalWidth,
      devicePixelRatio: dpr,
    );
    _deliveryGuy = icon;
    _deliveryGuyLoading = null;
    return icon;
  }

  /// Decodes [assetPath], scales for sharpness, and sizes for the map.
  static Future<BitmapDescriptor> fromAsset(
    String assetPath, {
    required double logicalWidth,
    double devicePixelRatio = 2.0,
  }) async {
    final dpr = devicePixelRatio.clamp(1.0, 3.0);
    final targetWidth = (logicalWidth * dpr).round();
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    final heightPx = frame.image.height.toDouble();
    final widthPx = frame.image.width.toDouble();
    frame.image.dispose();
    if (byteData == null || widthPx <= 0) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    final logicalHeight = logicalWidth * (heightPx / widthPx);
    return BitmapDescriptor.bytes(
      Uint8List.fromList(byteData.buffer.asUint8List()),
      width: logicalWidth,
      height: logicalHeight,
    );
  }
}
