import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/notifications/fcm_local_notification.dart';
import 'package:hudhud_delivery_driver/core/notifications/fcm_payload_spec.dart';

void main() {
  test('payload spec matches local notification channel and sound', () {
    expect(FcmPayloadSpec.preferredChannelId, FcmLocalNotification.channelId);
    expect(FcmPayloadSpec.androidSound, FcmLocalNotification.androidSoundResource);
    expect(FcmPayloadSpec.iosSound, FcmLocalNotification.iosSoundFile);
    expect(FcmPayloadSpec.preferredChannelId, 'transactional_v3');
  });
}
