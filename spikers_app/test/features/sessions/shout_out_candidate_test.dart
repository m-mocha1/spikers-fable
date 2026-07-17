import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/sessions/domain/shout_out_candidate.dart';

void main() {
  // A session that ended [endedAgo] before [now], with the given roster.
  SessionModel session(
    String id, {
    required Duration endedAgo,
    List<String> attendedIds = const ['me', 'u2'],
    DateTime? now,
  }) {
    final reference = now ?? DateTime(2026, 6, 10, 12);
    final end = reference.subtract(endedAgo);
    return SessionModel(
      id: id,
      title: id,
      location: 'hall',
      gender: 'mixed',
      minAge: 0,
      maxAge: 99,
      startTime: end.subtract(const Duration(hours: 2)),
      endTime: end,
      maxPlayers: 10,
      coachId: 'c1',
      attendeeIds: attendedIds,
      attendedIds: attendedIds,
      createdAt: DateTime(2026),
    );
  }

  final now = DateTime(2026, 6, 10, 12);

  SessionModel? pick(
    List<SessionModel> sessions, {
    Set<String> prompted = const {},
    Duration window = const Duration(days: 7),
  }) =>
      pickShoutOutSession(
        sessions: sessions,
        uid: 'me',
        now: now,
        promptedSessionIds: prompted,
        window: window,
      );

  test('returns null when there are no sessions', () {
    expect(pick(const []), isNull);
  });

  test('picks a recently-ended attended session with other attendees', () {
    final s = session('s1', endedAgo: const Duration(hours: 2));
    expect(pick([s])?.id, 's1');
  });

  test('picks the most recently ended among several eligible', () {
    final older = session('older', endedAgo: const Duration(days: 3));
    final newer = session('newer', endedAgo: const Duration(hours: 4));
    final oldest = session('oldest', endedAgo: const Duration(days: 6));
    expect(pick([older, newer, oldest])?.id, 'newer');
  });

  test('skips sessions that have not ended yet', () {
    final future = session('future', endedAgo: const Duration(hours: -2));
    expect(pick([future]), isNull);
  });

  test('skips sessions older than the window', () {
    final stale = session('stale', endedAgo: const Duration(days: 8));
    expect(pick([stale]), isNull);
  });

  test('honours a custom window', () {
    final s = session('s1', endedAgo: const Duration(days: 20));
    expect(pick([s], window: const Duration(days: 30))?.id, 's1');
  });

  test('skips sessions already prompted', () {
    final s = session('s1', endedAgo: const Duration(hours: 2));
    expect(pick([s], prompted: {'s1'}), isNull);
  });

  test('falls back to the next eligible when the newest is already prompted',
      () {
    final newer = session('newer', endedAgo: const Duration(hours: 4));
    final older = session('older', endedAgo: const Duration(days: 2));
    expect(pick([newer, older], prompted: {'newer'})?.id, 'older');
  });

  test('skips sessions where the user is the only attendee', () {
    final solo = session('solo', endedAgo: const Duration(hours: 2),
        attendedIds: const ['me']);
    expect(pick([solo]), isNull);
  });

  test('skips sessions with an empty roster', () {
    final empty = session('empty', endedAgo: const Duration(hours: 2),
        attendedIds: const []);
    expect(pick([empty]), isNull);
  });
}
