import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/app_upgrade_alert.dart';
import 'package:spikers_app/core/widgets/floating_nav_bar.dart';
import 'package:spikers_app/core/widgets/gradient_background.dart';
import 'package:spikers_app/core/widgets/retracting_app_bar.dart';
import 'package:spikers_app/core/widgets/scroll_retraction.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// The settled tab. Owned by [PageView.onPageChanged] — whether the user got
  /// there by swiping or by tapping the nav bar — so it always agrees with what
  /// is on screen.
  int _index = 0;

  final _pageController = PageController();

  /// 1 == app bar and nav bar fully shown, 0 == both retracted.
  late final AnimationController _barsController = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: 1,
  );

  late final ScrollRetraction _bars = ScrollRetraction(_barsController);

  late final Animation<double> _barsFactor = CurvedAnimation(
    parent: _barsController,
    curve: AppMotion.ambient,
  );

  /// Slides the nav bar off the bottom edge by its own height. The body already
  /// runs underneath it (`extendBody`), so unlike the app bar this frees its
  /// space by translating — no relayout, and the FAB stays put.
  late final Animation<Offset> _navSlide = Tween(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(_barsFactor);

  @override
  void dispose() {
    _pageController.dispose();
    _barsController.dispose();
    super.dispose();
  }

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

    final tabs = <Widget>[
      const SessionsTab(),
      // The roster (full users collection) is staff-only readable, so players
      // get the peer tab instead.
      isCoach ? const PlayersTab() : const PlayersPeerTab(),
      const ProfileTab(),
    ];

    final appBar = AppBar(
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
        // The roster (full users collection) is only readable by staff, so
        // the export is coach-gated; players get the peer tab instead.
        if (_index == 1 && isCoach)
          IconButton(
            tooltip: l.exportAttendance,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => context.push(Routes.exportOptions),
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
    );

    // The gradient sits outside the pager so it stays put while the tabs
    // slide across it. Swiping runs Sessions → Players → Profile; direction
    // mirrors itself under RTL along with the nav bar.
    //
    // Every tab's list feeds the bars from here, so scrolling any of them down
    // hands the space to the content and scrolling back up returns the chrome.
    final body = GradientBackground(
      child: RetractOnScroll(
        retraction: _bars,
        child: PageView(
          controller: _pageController,
          onPageChanged: (i) {
            // Each tab keeps its own scroll offset, so how far the last one was
            // scrolled says nothing about this one: start it with the bars back.
            _bars.reveal();
            setState(() => _index = i);
          },
          children: [for (final tab in tabs) _KeepAlivePage(child: tab)],
        ),
      ),
    );

    final fab = (isCoach && _index == 0)
        ? FloatingActionButton.small(
            tooltip: l.newSession,
            onPressed: () => _showSessionOptions(context, l),
            child: const Icon(Icons.add),
          ).animate().scale(
            duration: AppMotion.normal,
            curve: Curves.easeOutBack,
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
          )
        : null;

    final navBar = SlideTransition(
      position: _navSlide,
      child: FloatingNavBar(
        currentIndex: _index,
        // Tapping slides the same way a swipe does, so both gestures read as
        // one thing. `onPageChanged` picks up `_index` from here.
        onTap: (i) {
          HapticFeedback.selectionClick();
          _pageController.animateToPage(
            i,
            duration: AppMotion.normal,
            curve: AppMotion.enter,
          );
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

    // Home is the app's landing screen after auth, so it's where we check the
    // store for a newer build and prompt the user to update (see
    // [AppUpgradeAlert]).
    return AppUpgradeAlert(
      // Only the Scaffold can act on the app bar's changing height, so it is
      // what rebuilds per frame. Everything expensive is built above and passed
      // in by reference, so those subtrees are reused rather than rebuilt 60
      // times a second — which would restart the FAB's entrance animation.
      child: AnimatedBuilder(
        animation: _barsFactor,
        builder: (_, _) => Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          appBar: RetractingAppBar(factor: _barsFactor.value, bar: appBar),
          body: body,
          floatingActionButton: fab,
          bottomNavigationBar: navBar,
        ),
      ),
    );
  }
}

/// Keeps a swiped-away tab mounted.
///
/// [PageView] disposes pages once they leave the viewport, which would reset
/// each tab's scroll position and clear the players search box on every swipe —
/// state the previous `IndexedStack` held onto for free.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.
    return widget.child;
  }
}
