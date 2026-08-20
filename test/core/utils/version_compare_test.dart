import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/version_compare.dart';

void main() {
  group('VersionCompare', () {
    test('orders semantic versions', () {
      expect(VersionCompare.compare('1.0.0', '1.0.1'), lessThan(0));
      expect(VersionCompare.compare('1.2.0', '1.1.9'), greaterThan(0));
      expect(VersionCompare.compare('2.0.0', '2.0.0'), 0);
    });

    test('ignores build metadata and prerelease suffixes', () {
      expect(VersionCompare.compare('1.0.0+10', '1.0.0'), 0);
      expect(VersionCompare.isOlderThan('1.0.0-beta', '1.0.1'), isTrue);
    });

    test('pads missing segments', () {
      expect(VersionCompare.isOlderThan('1.0', '1.0.1'), isTrue);
      expect(VersionCompare.isOlderThan('1.2.3', '1.2'), isFalse);
    });
  });
}
