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

final announcementsProvider =
    StreamProvider.autoDispose<List<AnnouncementModel>>(
  (ref) => ref.watch(announcementsRepositoryProvider).watchAll(),
);

/// Not autoDispose — the home-screen bell badge watches it for the whole
/// session.
final latestAnnouncementAtProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(announcementsRepositoryProvider).watchLatestAt(),
);

final hasUnreadAnnouncementsProvider = Provider<bool>((ref) {
  final latest = ref.watch(latestAnnouncementAtProvider).value;
  if (latest == null) return false;
  final seen =
      ref.watch(currentUserProvider).value?.lastSeenAnnouncementsAt;
  return seen == null || latest.isAfter(seen);
});

/// Stamps lastSeenAnnouncementsAt, skipping the write when nothing is unread.
Future<void> markAnnouncementsRead(WidgetRef ref) async {
  if (!ref.read(hasUnreadAnnouncementsProvider)) return;
  final uid = ref.read(currentUserProvider).value?.uid;
  if (uid == null) return;
  await ref.read(announcementsRepositoryProvider).markRead(uid);
}
