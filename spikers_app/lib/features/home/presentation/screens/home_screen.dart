import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/floating_nav_bar.dart';
import 'package:spikers_app/core/widgets/gradient_background.dart';
import '../../../announcements/presentation/widgets/announcements_bell.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/application/notifications_service.dart';
import '../../../players/presentation/screens/players_peer_tab.dart';
import '../../../players/presentation/screens/players_tab.dart';
import '../../../sessions/presentation/screens/sessions_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  /// Bumped each time a tab is (re)selected so its entrance animation replays.
  /// One counter per tab slot, passed to the animated tabs as `revealGeneration`
  /// — the `IndexedStack` keeps tabs mounted, so without this they'd only ever
  /// animate once (at app launch, before the user even switches to them).
  final List<int> _reveal = [0, 0, 0];

  void _showSessionOptions(BuildContext context, AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.gold,
                child: Icon(Icons.add, color: AppColors.navyBlue),
              ),
              title: Text(
                l.newSession,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l.createSession,
                style: const TextStyle(color: AppColors.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push(Routes.createSession);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.navyBlue,
                child: Icon(Icons.flash_on_outlined, color: AppColors.gold),
              ),
              title: Text(
                l.quickSession,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l.selectTemplate,
                style: const TextStyle(color: AppColors.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push(Routes.quickSession);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.navyBlue,
                child: Icon(Icons.repeat, color: AppColors.gold),
              ),
              title: Text(
                l.recurringSessions,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l.recurringSessionsDesc,
                style: const TextStyle(color: AppColors.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push(Routes.recurringSessions);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isCoach = ref.watch(isCoachProvider);
    // Keeps the FCM tap-routing service alive while the home shell exists.
    ref.watch(notificationsServiceProvider);

    final tabs = isCoach
        ? [
            SessionsTab(revealGeneration: _reveal[0]),
            const PlayersTab(),
            ProfileTab(revealGeneration: _reveal[2]),
          ]
        : [
            SessionsTab(revealGeneration: _reveal[0]),
            const PlayersPeerTab(),
            ProfileTab(revealGeneration: _reveal[2]),
          ];
    final safeIndex = _index >= tabs.length ? 0 : _index;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l.appName),
        actions: [
          // History is open to everyone: players view past sessions to give
          // endorsements (only allowed once a session has ended).
          if (_index == 0)
            IconButton(
              tooltip: l.sessionsHistory,
              icon: const Icon(Icons.history),
              onPressed: () => context.push(Routes.sessionsHistory),
            ),
          if (_index == 1)
            IconButton(
              tooltip: l.coachesTab,
              icon: const Icon(Icons.sports_outlined),
              onPressed: () => context.push(Routes.coachesList),
            ),
          IconButton(
            tooltip: l.leaderboard,
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push(Routes.leaderboard),
          ),
          const AnnouncementsBell(),
        ],
      ),
      body: GradientBackground(
        child: IndexedStack(index: safeIndex, children: tabs),
      ),
      floatingActionButton: (isCoach && _index == 0)
          ? FloatingActionButton.small(
              onPressed: () => _showSessionOptions(context, l),
              child: const Icon(Icons.add),
            ).animate().scale(
              duration: AppMotion.normal,
              curve: Curves.easeOutBack,
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
            )
          : null,
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _index >= 3 ? 0 : _index,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() {
            if (i != _index) _reveal[i]++;
            _index = i;
          });
        },
        items: [
          FloatingNavItem(
            icon: Icons.sports_volleyball_outlined,
            activeIcon: Icons.sports_volleyball,
            label: l.sessions,
          ),
          FloatingNavItem(
            icon: Icons.group_outlined,
            activeIcon: Icons.group,
            label: l.playersTab,
          ),
          FloatingNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: l.profile,
          ),
        ],
      ),
    );
  }
}
