import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hudhud_delivery_driver/core/notifications/job_offer_alert_store.dart';
import 'package:hudhud_delivery_driver/core/notifications/legacy_notification_mapper.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

/// Loops the job-offer alert sound until the driver acknowledges it.
class JobOfferAlertSoundService {
  JobOfferAlertSoundService({
    required JobOfferAlertStore store,
    required AppLogger logger,
    AudioPlayer? player,
  })  : _store = store,
        _logger = logger,
        _player = player ?? AudioPlayer();

  static const _assetPath = 'sound/notification_sound.mp3';

  final JobOfferAlertStore _store;
  final AppLogger _logger;
  final AudioPlayer _player;

  bool _playing = false;

  bool get isPlaying => _playing;

  static bool shouldAlertForData(Map<String, dynamic> data) {
    final event = LegacyNotificationMapper.resolveEvent(data);
    if (event == NotificationEvents.otpRequired ||
        data['screen']?.toString() ==
            NotificationEvents.screenVerifyDelivery) {
      return false;
    }
    return NotificationEvents.isJobOfferEvent(event);
  }

  static bool shouldAlertForMessage(RemoteMessage message) =>
      shouldAlertForData(message.data);

  Future<void> handleJobOfferMessage(RemoteMessage message) async {
    if (!shouldAlertForMessage(message)) return;
    await _store.setPending(true);
    await startLoop();
  }

  Future<void> handleJobOfferData(Map<String, dynamic> data) async {
    if (!shouldAlertForData(data)) return;
    await _store.setPending(true);
  }

  Future<void> resumePendingAlert() async {
    if (!await _store.isPending()) return;
    await startLoop();
  }

  Future<void> startLoop() async {
    if (_playing) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(_assetPath));
      _playing = true;
    } catch (e, stackTrace) {
      _logger.error('Failed to start job-offer alert sound', e, stackTrace);
    }
  }

  Future<void> acknowledge() async {
    _playing = false;
    try {
      await _player.stop();
    } catch (e, stackTrace) {
      _logger.error('Failed to stop job-offer alert sound', e, stackTrace);
    }
    await _store.clearPending();
  }

  Future<void> dispose() async {
    await acknowledge();
    await _player.dispose();
  }
}
