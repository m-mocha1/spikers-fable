import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/announcements_remote_datasource.dart';
import '../../data/repositories/announcements_repository_impl.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcements_repository.dart';

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>(
  (ref) => AnnouncementsRepositoryImpl(
    AnnouncementsRemoteDataSource(ref.watch(firestoreProvider)),
  ),
);

/// Full announcement list, newest first. Not autoDispose — the home-screen
/// bell badge watches it (via visibleAnnouncementsProvider) for the whole
/// session, so it must stay alive while the screen is closed.
final announcementsProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  // announcements reads require email_verified in the rules. Watch the user
  // so this re-subscribes when verification flips, and return empty (not
  // PERMISSION_DENIED) while unverified. See upcomingSessionsProvider.
  final user = ref.watch(currentUserProvider).value;
  if (user == null ||
      !ref.watch(authRepositoryProvider).isEmailVerified) {
    return Stream.value(const []);
  }
  return ref.watch(announcementsRepositoryProvider).watchAll();
});

/// The announcements the current user is allowed to see. Coaches/admins see
/// everything; players see 'all' plus those targeting their own gender.
/// Audience filtering is done here (client-side) so no Firestore index or
/// backfill is required — see AnnouncementModel.visibleTo.
final visibleAnnouncementsProvider =
    Provider<AsyncValue<List<AnnouncementModel>>>((ref) {
  final all = ref.watch(announcementsProvider);
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const AsyncValue.loading();
  return all.whenData((list) => list
      .where((a) => a.visibleTo(isCoach: user.isCoach, gender: user.gender))
      .toList());
});

final hasUnreadAnnouncementsProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return false;
  final visible = ref.watch(visibleAnnouncementsProvider).value;
  if (visible == null || visible.isEmpty) return false;
  // watchAll orders by createdAt desc, so the first visible item is the latest.
  final latest = visible.first.createdAt;
  final seen = user.lastSeenAnnouncementsAt;
  return seen == null || latest.isAfter(seen);
});

/// Stamps lastSeenAnnouncementsAt, skipping the write when nothing is unread.
Future<void> markAnnouncementsRead(WidgetRef ref) async {
  if (!ref.read(hasUnreadAnnouncementsProvider)) return;
  final uid = ref.read(currentUserProvider).value?.uid;
  if (uid == null) return;
  await ref.read(announcementsRepositoryProvider).markRead(uid);
}
