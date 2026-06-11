import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification_service.dart';

class FcmService {
  static Future<void> init() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await LocalNotificationService.init();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }
}
