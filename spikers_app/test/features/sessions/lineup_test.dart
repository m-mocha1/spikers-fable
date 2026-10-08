import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/sessions/domain/lineup.dart';

void main() {
  List<String> players(int n) => [for (var i = 0; i < n; i++) 'p$i'];
  const a0 = LineupSlot(LineupArea.teamA, 0);
  const a1 = LineupSlot(LineupArea.teamA, 1);
  const b0 = LineupSlot(LineupArea.teamB, 0);
  const bench0 = LineupSlot(LineupArea.bench, 0);

  /// An empty line-up whose bench is sized for [n] attendees.
  Lineup sizedFor(int n) => Lineup.empty().reconcile(players(n));

  group('Lineup.shuffle', () {
    test('with 20 players: 12 on court, 8 subs, nobody left over', () {
      final ids = players(20);
      final l = Lineup.shuffle(ids, Random(1));
      final placed =
          [...l.teamA, ...l.teamB, ...l.bench].whereType<String>().toList();
      expect(l.teamA.whereType<String>(), hasLength(6));
      expect(l.teamB.whereType<String>(), hasLength(6));
      expect(l.bench, hasLength(8));
      expect(l.bench.whereType<String>(), hasLength(8));
      expect(placed.toSet(), ids.toSet());
      expect(l.pool(ids), isEmpty);
    });

    test('with 14 players there are exactly 2 sub slots', () {
      final l = Lineup.shuffle(players(14), Random(1));
      expect(l.bench, hasLength(2));
      expect(l.bench.whereType<String>(), hasLength(2));
    });

    test('with 8 players Team A is full and Team B gets 2', () {
      final l = Lineup.shuffle(players(8), Random(1));
      expect(l.teamA.whereType<String>(), hasLength(6));
      expect(l.teamB.whereType<String>(), hasLength(2));
      expect(l.bench, isEmpty);
    });

    test('a non-list bench is treated as empty instead of throwing', () {
      final l = Lineup.fromMap({'bench': 'oops'});
      expect(l.bench, isEmpty);
    });

    test('is deterministic for a seeded Random', () {
      final a = Lineup.shuffle(players(14), Random(42));
      final b = Lineup.shuffle(players(14), Random(42));
      expect(a.teamA, b.teamA);
      expect(a.teamB, b.teamB);
      expect(a.bench, b.bench);
    });
  });

  group('Lineup.move', () {
    test('moves a pool player into an empty spot', () {
      final l = Lineup.empty().move('a', a0);
      expect(l.teamA[0], 'a');
      expect(l.pool(['a', 'b']), ['b']);
    });

    test('swaps players across teams', () {
      final l = Lineup.empty().move('a', a0).move('b', b0);
      final swapped = l.move('b', a0);
      expect(swapped.teamA[0], 'b');
      expect(swapped.teamB[0], 'a');
    });

    test('moves a sub from the bench onto the court', () {
      final l = sizedFor(14).move('a', bench0).move('a', b0);
      expect(l.bench[0], isNull);
      expect(l.teamB[0], 'a');
    });

    test('displaced occupant drops to the pool when mover came from pool', () {
      final l = Lineup.empty().move('a', a0).move('b', a0);
      expect(l.teamA[0], 'b');
      expect(l.slotOf('a'), const LineupSlot.pool());
    });

    test('moving within a team vacates the old spot', () {
      final l = Lineup.empty().move('a', a0).move('a', a1);
      expect(l.teamA[0], isNull);
      expect(l.teamA[1], 'a');
    });

    test('moving to the pool unassigns the player', () {
      final l = Lineup.empty().move('a', a0).move('a', const LineupSlot.pool());
      expect(l.isEmpty, isTrue);
    });

    test('does not mutate the original line-up', () {
      final original = Lineup.empty();
      original.move('a', a0);
      expect(original.isEmpty, isTrue);
    });
  });

  group('Lineup.reconcile', () {
    test('removes players who are no longer attendees', () {
      final l = sizedFor(14).move('a', a0).move('b', bench0).move('c', b0);
      final r = l.reconcile(['b', ...players(13)]);
      expect(r.teamA[0], isNull);
      expect(r.teamB[0], isNull);
      expect(r.bench[0], 'b');
    });

    test('returns the same instance when nothing changed', () {
      final l = Lineup.empty().move('a', a0);
      expect(identical(l.reconcile(['a', 'b']), l), isTrue);
    });

    test('bench grows with the roster, keeping placed subs', () {
      final l = sizedFor(14).move('p0', bench0);
      final r = l.reconcile(players(20));
      expect(r.bench, hasLength(8));
      expect(r.bench[0], 'p0');
    });

    test('shrinking bench moves subs up, overflow returns to the pool', () {
      // 15 players → 3 sub slots, all filled.
      var l = sizedFor(15);
      for (var i = 0; i < 3; i++) {
        l = l.move('p$i', LineupSlot(LineupArea.bench, i));
      }
      // p0 leaves and p14 leaves → 13 players → 1 slot for p1/p2.
      final remaining = players(15).where((u) => u != 'p0' && u != 'p14');
      final r = l.reconcile(remaining.toList());
      expect(r.bench, hasLength(1));
      expect(r.bench[0], 'p1');
      expect(r.slotOf('p2'), const LineupSlot.pool());
    });

    test('12 or fewer players means no bench', () {
      expect(sizedFor(12).bench, isEmpty);
      expect(sizedFor(5).bench, isEmpty);
    });
  });

  group('Lineup map round-trip', () {
    test('toMap then fromMap keeps every spot', () {
      final l = Lineup.shuffle(players(14), Random(3));
      final back = Lineup.fromMap(l.toMap());
      expect(back.teamA, l.teamA);
      expect(back.teamB, l.teamB);
      expect(back.bench, l.bench);
    });

    test('malformed data pads, trims and drops non-uids', () {
      final l = Lineup.fromMap({
        'teamA': ['a', null, 7, ''],
        'teamB': List.filled(9, 'b'),
      });
      expect(l.teamA, ['a', null, null, null, null, null]);
      expect(l.teamB, List.filled(6, 'b'));
      expect(l.bench, isEmpty);
    });
  });
}
