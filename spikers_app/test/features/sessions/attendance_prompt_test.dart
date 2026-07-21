import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/sessions/domain/attendance_prompt.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';

void main() {
  final now = DateTime(2026, 6, 10, 12);

  // A session ending [endedAgo] before [now], owned by [coachId], with a roster
  // and an attendance-taken flag.
  SessionModel session(
    String id, {
    required Duration endedAgo,
    String coachId = 'c1',
    List<String> attendeeIds = const ['p1', 'p2'],
    bool attendanceConfirmed = false,
  }) {
    final end = now.subtract(endedAgo);
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
      coachId: coachId,
      attendeeIds: attendeeIds,
      attendanceConfirmed: attendanceConfirmed,
      createdAt: DateTime(2026),
    );
  }

  SessionModel? pick(
    List<SessionModel> sessions, {
    Set<String> prompted = const {},
  }) =>
      pickAttendanceSession(
        sessions: sessions,
        uid: 'c1',
        now: now,
        promptedSessionIds: prompted,
      );

  group('pickAttendanceSession', () {
    test('returns null when there are no sessions', () {
      expect(pick(const []), isNull);
    });

    test('picks a recently-ended owned session needing attendance', () {
      expect(pick([session('s1', endedAgo: const Duration(hours: 1))])?.id,
          's1');
    });

    test('picks the most recently ended among several eligible', () {
      final older = session('older', endedAgo: const Duration(days: 2));
      final newer = session('newer', endedAgo: const Duration(hours: 3));
      expect(pick([older, newer])?.id, 'newer');
    });

    test('skips sessions the coach does not own', () {
      expect(
        pick([
          session('s1', endedAgo: const Duration(hours: 1), coachId: 'other')
        ]),
        isNull,
      );
    });

    test('skips sessions that have not ended yet', () {
      expect(
        pick([session('future', endedAgo: const Duration(hours: -2))]),
        isNull,
      );
    });

    test('skips sessions older than the window', () {
      expect(
        pick([session('stale', endedAgo: const Duration(days: 4))]),
        isNull,
      );
    });

    test('skips sessions that already had attendance taken', () {
      expect(
        pick([
          session('done',
              endedAgo: const Duration(hours: 1), attendanceConfirmed: true)
        ]),
        isNull,
      );
    });

    test('skips sessions with an empty roster', () {
      expect(
        pick([
          session('empty',
              endedAgo: const Duration(hours: 1), attendeeIds: const [])
        ]),
        isNull,
      );
    });

    test('skips sessions already prompted', () {
      final s = session('s1', endedAgo: const Duration(hours: 1));
      expect(pick([s], prompted: {'s1'}), isNull);
    });

    test('falls back to the next eligible when the newest is already prompted',
        () {
      final newer = session('newer', endedAgo: const Duration(hours: 3));
      final older = session('older', endedAgo: const Duration(days: 1));
      expect(pick([newer, older], prompted: {'newer'})?.id, 'older');
    });
  });

  group('coachSessionsNeedingAttendance', () {
    List<SessionModel> todo(List<SessionModel> sessions) =>
        coachSessionsNeedingAttendance(
          sessions: sessions,
          uid: 'c1',
          now: now,
        );

    test('ignores the prompted flag — dismissed work still counts', () {
      final a = session('a', endedAgo: const Duration(hours: 1));
      final b = session('b', endedAgo: const Duration(hours: 5));
      final result = todo([a, b]);
      expect(result.map((s) => s.id), ['a', 'b']); // newest-ended first
    });

    test('excludes confirmed, foreign, future and stale sessions', () {
      final result = todo([
        session('ok', endedAgo: const Duration(hours: 1)),
        session('done',
            endedAgo: const Duration(hours: 1), attendanceConfirmed: true),
        session('foreign',
            endedAgo: const Duration(hours: 1), coachId: 'other'),
        session('future', endedAgo: const Duration(hours: -1)),
        session('stale', endedAgo: const Duration(days: 5)),
      ]);
      expect(result.map((s) => s.id), ['ok']);
    });
  });
}
