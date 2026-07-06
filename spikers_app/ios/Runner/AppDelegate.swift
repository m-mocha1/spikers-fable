import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Plugins MUST register here, before UIKit posts
    // UIApplicationDidFinishLaunchingNotification (right after this method
    // returns). firebase_messaging performs all of its APNs setup — the
    // registerForRemoteNotifications() call that makes iOS issue a device
    // token, the swizzling that captures it, and the UNUserNotificationCenter
    // delegate used for foreground/tap events — inside an observer for that
    // notification, added in the plugin's init. Registering lazily via
    // didInitializeImplicitFlutterEngine (the new-template way) runs only when
    // the Flutter view first loads, AFTER the notification has fired, so none
    // of that setup ever ran: iOS never requested an APNs token and getToken()
    // threw apns-token-not-set forever.
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Hand the APNs device token to Firebase Messaging explicitly rather than
  // relying on swizzling alone. If Firebase isn't configured yet (Dart-side
  // Firebase.initializeApp still running), skip it — super forwards the token
  // to the plugin, which caches it and applies it once Firebase is up.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(
      application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Surface registration failures (e.g. missing Push entitlement / provisioning
  // profile without the Push Notifications capability) instead of failing silently.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[FCM] APNs registration FAILED: \(error.localizedDescription)")
    super.application(
      application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
