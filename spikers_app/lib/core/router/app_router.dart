import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/announcements/domain/entities/announcement.dart';
import '../../features/announcements/presentation/screens/announcements_screen.dart';
import '../../features/announcements/presentation/screens/create_announcement_screen.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/presentation/screens/email_change_notice_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/coaches/presentation/screens/coaches_list_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/payments/presentation/screens/payment_history_screen.dart';
import '../../features/players/presentation/screens/export_options_screen.dart';
import '../../features/players/presentation/screens/player_profile_screen.dart';
import '../../features/sessions/domain/entities/recurring_session_model.dart';
import '../../features/sessions/domain/entities/session_model.dart';
import '../../features/sessions/presentation/screens/create_recurring_session_screen.dart';
import '../../features/sessions/presentation/screens/create_session_screen.dart';
import '../../features/sessions/presentation/screens/recurring_sessions_screen.dart';
import '../../features/sessions/presentation/screens/session_chat_screen.dart';
import '../../features/sessions/presentation/screens/session_detail_screen.dart';
import '../../features/sessions/presentation/screens/sessions_history_screen.dart';

abstract class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const emailChangeNotice = '/email-change-notice';
  static const home = '/home';
  static const sessionDetail = '/session-detail';
  static const createSession = '/create-session';
  static const sessionChat = '/session-chat';
  static const playerProfile = '/player-profile';
  static const announcements = '/announcements';
  static const createAnnouncement = '/create-announcement';
  static const sessionsHistory = '/sessions-history';
  static const leaderboard = '/leaderboard';
  static const recurringSessions = '/recurring-sessions';
  static const createRecurring = '/create-recurring';
  static const coachesList = '/coaches-list';
  static const paymentHistory = '/payment-history';
  static const exportOptions = '/export-options';
}

/// Replaces the GetX CoachOnlyMiddleware: signed-out users land on login,
/// non-coaches bounce back home. Reads the repository singleton because
/// redirects run outside the widget tree.
String? _coachOnly(BuildContext context, GoRouterState state) {
  final repo = AuthRepositoryImpl.instance;
  if (!repo.isSignedIn) return Routes.login;
  if (repo.currentUserNow?.isCoach != true) return Routes.home;
  return null;
}

final appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
    GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (_, _) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: Routes.verifyEmail,
      builder: (_, _) => const VerifyEmailScreen(),
    ),
    GoRoute(
      path: Routes.emailChangeNotice,
      builder: (_, state) =>
          EmailChangeNoticeScreen(newEmail: state.extra as String? ?? ''),
    ),
    GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: Routes.sessionDetail,
      builder: (_, state) {
        final extra = state.extra;
        return SessionDetailScreen(
          session: extra is SessionModel ? extra : null,
          sessionId: extra is String ? extra : null,
        );
      },
    ),
    GoRoute(
      path: Routes.createSession,
      redirect: _coachOnly,
      builder: (_, _) => const CreateSessionScreen(),
    ),
    GoRoute(
      path: Routes.sessionChat,
      builder: (_, state) {
        final args = state.extra is Map ? state.extra as Map : const {};
        return SessionChatScreen(
          sessionId: args['id']?.toString() ?? '',
          sessionTitle: args['title']?.toString() ?? '',
        );
      },
    ),
    // No _coachOnly redirect: any signed-in user may open a player profile.
    // PlayerProfileScreen itself branches by viewer role — non-coaches get the
    // public view (games played + endorsements only), coaches get full access.
    GoRoute(
      path: Routes.playerProfile,
      builder: (_, state) =>
          PlayerProfileScreen(userId: state.extra as String?),
    ),
    GoRoute(
      path: Routes.announcements,
      builder: (_, _) => const AnnouncementsScreen(),
    ),
    GoRoute(
      path: Routes.createAnnouncement,
      redirect: _coachOnly,
      builder: (_, state) => CreateAnnouncementScreen(
        existing: state.extra is AnnouncementModel
            ? state.extra as AnnouncementModel
            : null,
      ),
    ),
    // No _coachOnly redirect: players reach session history to give
    // endorsements (only allowed on ended sessions). Reads are verified-user
    // gated by the Firestore rules on sessions_history.
    GoRoute(
      path: Routes.sessionsHistory,
      builder: (_, _) => const SessionsHistoryScreen(),
    ),
    GoRoute(
      path: Routes.leaderboard,
      builder: (_, _) => const LeaderboardScreen(),
    ),
    GoRoute(
      path: Routes.recurringSessions,
      redirect: _coachOnly,
      builder: (_, _) => const RecurringSessionsScreen(),
    ),
    GoRoute(
      path: Routes.createRecurring,
      redirect: _coachOnly,
      builder: (_, state) => CreateRecurringSessionScreen(
        editing: state.extra is RecurringSessionModel
            ? state.extra as RecurringSessionModel
            : null,
      ),
    ),
    GoRoute(
      path: Routes.coachesList,
      builder: (_, _) => const CoachesListScreen(),
    ),
    // No _coachOnly redirect: owners may view their own history and coaches
    // any player's — the /payments read rule enforces the real boundary.
    GoRoute(
      path: Routes.paymentHistory,
      builder: (_, state) =>
          PaymentHistoryScreen(userId: state.uri.queryParameters['uid'] ?? ''),
    ),
    GoRoute(
      path: Routes.exportOptions,
      redirect: _coachOnly,
      builder: (_, _) => const ExportOptionsScreen(),
    ),
  ],
);
