import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'controller/locale_controller.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'routes/app_routes.dart';

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage _) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
    webProvider: ReCaptchaV3Provider('6LfUyvUsAAAAABb7HEdQnNne18CUEiPOCqCOSjCR'),
  );
  FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);
  runApp(const ProviderScope(child: SpikersApp()));
}

class SpikersApp extends StatelessWidget {
  const SpikersApp({super.key});

// Wednesday

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Jerusalem Spikers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: Routes.splash,
      getPages: appPages,
      initialBinding: BindingsBuilder(() {
        Get.put(LocaleController(), permanent: true);
        // Kick off session restore early so splash's `ready` await is short.
        AuthRepositoryImpl.instance;
      }),
      locale: const Locale('en'),
      fallbackLocale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) {
        final localized = Obx(() {
          final isArabic =
              Get.find<LocaleController>().currentLocale.value.languageCode ==
                  'ar';
          return Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          );
        });
        if (kIsWeb) {
          return Container(
            color: AppColors.navyBlue,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768),
                child: localized,
              ),
            ),
          );
        }
        return localized;
      },
    );
  }
}
