import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Maximum profile photo upload size (nginx default is often 1 MB).
const maxProfilePhotoBytes = 1 * 1024 * 1024;

/// Longest edge for profile photos before upload.
const maxProfilePhotoLongEdge = 1024;

/// Compresses [input] to JPEG for registration upload.
///
/// Retries at lower quality if the result still exceeds [maxProfilePhotoBytes].
/// Throws [StateError] when compression fails or the file stays too large.
Future<File> compressProfilePhoto(File input) async {
  final tempDir = await getTemporaryDirectory();
  final baseName =
      'profile_${DateTime.now().millisecondsSinceEpoch}_${input.hashCode}';

  for (final quality in [75, 60, 50]) {
    final targetPath = '${tempDir.path}/${baseName}_q$quality.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxProfilePhotoLongEdge,
      minHeight: maxProfilePhotoLongEdge,
      format: CompressFormat.jpeg,
    );

    if (result == null) continue;

    final compressed = File(result.path);
    if (!compressed.existsSync()) continue;

    final size = compressed.lengthSync();
    if (size <= maxProfilePhotoBytes) {
      return compressed;
    }
  }

  throw StateError(
    'Photo is still too large after compression. Please choose a smaller image.',
  );
}
