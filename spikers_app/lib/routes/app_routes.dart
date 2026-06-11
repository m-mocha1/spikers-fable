import 'package:flutter/material.dart' show RouteSettings;
import 'package:get/get.dart';
import '../controller/auth_controller.dart';
import '../controller/notification_controller.dart';
import '../controller/payment_controller.dart';
import '../controller/session_controller.dart';
import '../controller/template_controller.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/email_change_notice_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/sessions/session_detail_screen.dart';
import '../screens/sessions/create_session_screen.dart';
import '../screens/sessions/quick_session_screen.dart';
import '../screens/sessions/session_chat_screen.dart';
import '../screens/sessions/sessions_history_screen.dart';
import '../screens/players/player_profile_screen.dart';
import '../screens/coaches/coaches_list_screen.dart';
import '../features/announcements/presentation/screens/announcements_screen.dart';
import '../features/announcements/presentation/screens/create_announcement_screen.dart';
import '../controller/recurring_session_controller.dart';
import '../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../screens/sessions/recurring_sessions_screen.dart';
import '../screens/sessions/create_recurring_session_screen.dart';

abstract class Routes {
  static const splash         = '/';
  static const login          = '/login';
  static const register       = '/register';
  static const forgotPassword     = '/forgot-password';
  static const verifyEmail        = '/verify-email';
  static const emailChangeNotice  = '/email-change-notice';
  static const home               = '/home';
  static const sessionDetail  = '/session-detail';
  static const createSession  = '/create-session';
  static const quickSession   = '/quick-session';
  static const sessionChat    = '/session-chat';
  static const playerProfile  = '/player-profile';
  static const announcements      = '/announcements';
  static const createAnnouncement = '/create-announcement';
  static const sessionsHistory    = '/sessions-history';
  static const leaderboard        = '/leaderboard';
  static const recurringSessions  = '/recurring-sessions';
  static const createRecurring    = '/create-recurring';
  static const coachesList        = '/coaches-list';
}

final List<GetPage> appPages = [
  GetPage(name: Routes.splash,         page: () => const SplashScreen()),
  GetPage(name: Routes.login,          page: () => const LoginScreen()),
  GetPage(name: Routes.register,       page: () => const RegisterScreen()),
  GetPage(name: Routes.forgotPassword, page: () => const ForgotPasswordScreen()),
  GetPage(name: Routes.verifyEmail,    page: () => const VerifyEmailScreen()),
  GetPage(name: Routes.emailChangeNotice, page: () => const EmailChangeNoticeScreen()),
  GetPage(
    name: Routes.home,
    page: () => const HomeScreen(),
    binding: BindingsBuilder(() {
      Get.put(SessionController(), permanent: true);
      Get.put(NotificationController(), permanent: true);
      Get.put(TemplateController(), permanent: true);
      Get.put(PaymentController(), permanent: true);
    }),
  ),
  GetPage(name: Routes.sessionDetail,  page: () => const SessionDetailScreen()),
  GetPage(
    name: Routes.createSession,
    page: () => const CreateSessionScreen(),
    middlewares: [CoachOnlyMiddleware()],
  ),
  GetPage(
    name: Routes.quickSession,
    page: () => const QuickSessionScreen(),
    middlewares: [CoachOnlyMiddleware()],
  ),
  GetPage(name: Routes.sessionChat, page: () => const SessionChatScreen()),
  GetPage(
    name: Routes.playerProfile,
    page: () => const PlayerProfileScreen(),
    middlewares: [CoachOnlyMiddleware()],
  ),
  GetPage(
    name: Routes.announcements,
    page: () => const AnnouncementsScreen(),
  ),
  GetPage(
    name: Routes.createAnnouncement,
    page: () => const CreateAnnouncementScreen(),
    middlewares: [CoachOnlyMiddleware()],
  ),
  GetPage(
    name: Routes.sessionsHistory,
    page: () => const SessionsHistoryScreen(),
    middlewares: [CoachOnlyMiddleware()],
  ),
  // Riverpod feature — no GetX binding; providers are autoDispose.
  GetPage(
    name: Routes.leaderboard,
    page: () => const LeaderboardScreen(),
  ),
  GetPage(
    name: Routes.recurringSessions,
    page: () => const RecurringSessionsScreen(),
    middlewares: [CoachOnlyMiddleware()],
    binding: BindingsBuilder(() {
      if (!Get.isRegistered<RecurringSessionController>()) {
        Get.put(RecurringSessionController());
      }
    }),
  ),
  GetPage(
    name: Routes.createRecurring,
    page: () => const CreateRecurringSessionScreen(),
    middlewares: [CoachOnlyMiddleware()],
    binding: BindingsBuilder(() {
      if (!Get.isRegistered<RecurringSessionController>()) {
        Get.put(RecurringSessionController());
      }
    }),
  ),
  GetPage(
    name: Routes.coachesList,
    page: () => const CoachesListScreen(),
  ),
];

class CoachOnlyMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    try {
      final auth = Get.find<AuthController>();
      if (!auth.isCoach) return RouteSettings(name: Routes.home);
    } catch (_) {
      return RouteSettings(name: Routes.login);
    }
    return null;
  }
}
