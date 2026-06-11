import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/services/fcm_service.dart';
import '../core/services/local_notification_service.dart';
import '../routes/app_routes.dart';

class NotificationController extends GetxController {
  StreamSubscription? _onMessageSub;
  StreamSubscription? _onMessageOpenedSub;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    if (kDebugMode) return;
    await FcmService.init();

    // Foreground: FCM delivers silently on iOS when setForegroundNotificationPresentationOptions
    // is configured — we show the banner ourselves via local notifications.
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n != null) {
        LocalNotificationService.show(
          title: n.title ?? '',
          body: n.body ?? '',
        );
      }
    });

    // Background: user tapped the system notification
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Terminated: app launched by tapping a notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleMessage(initial);
  }

  @override
  void onClose() {
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    super.onClose();
  }

  void _handleMessage(RemoteMessage message) {
    final sessionId = message.data['sessionId'] as String?;
    if (sessionId != null && sessionId.isNotEmpty) {
      Get.toNamed(Routes.sessionDetail, arguments: sessionId);
    }
  }
}
