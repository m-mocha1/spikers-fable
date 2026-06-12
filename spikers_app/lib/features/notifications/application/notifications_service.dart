import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../../auth/presentation/providers/auth_providers.dart';

/// Foreground/background FCM wiring: shows local banners for foreground
/// messages and routes notification taps to the session detail screen.
class NotificationsService {
  StreamSubscription? _onMessageSub;
  StreamSubscription? _onMessageOpenedSub;

  Future<void> init() async {
    if (kDebugMode) return;
    await FcmService.init();

    // Foreground: FCM delivers silently on iOS when
    // setForegroundNotificationPresentationOptions is configured — we show
    // the banner ourselves via local notifications.
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

  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
  }

  void _handleMessage(RemoteMessage message) {
    final sessionId = message.data['sessionId'] as String?;
    if (sessionId != null && sessionId.isNotEmpty) {
      appRouter.push(Routes.sessionDetail, extra: sessionId);
    }
  }
}

/// Alive only while someone is signed in: keys off currentUserProvider, so
/// signing out disposes the listeners and the next sign-in re-creates them.
/// The home shell watches this to keep it running.
final notificationsServiceProvider = Provider<NotificationsService?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  final service = NotificationsService()..init();
  ref.onDispose(service.dispose);
  return service;
});
