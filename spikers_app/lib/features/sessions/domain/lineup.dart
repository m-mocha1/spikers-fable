import 'dart:math';

/// Where a player sits in a [Lineup]: on one of the two teams' courts, on the
/// shared sideline bench, or unplaced in the pool of remaining attendees.
enum LineupArea { teamA, teamB, bench, pool }

/// A single spot in a [Lineup]. [index] is 0-based; for a team it maps to
/// volleyball position `index + 1`. Ignored for [LineupArea.pool].
class LineupSlot {
  final LineupArea area;
  final int index;

  const LineupSlot(this.area, this.index);
  const LineupSlot.pool()
      : area = LineupArea.pool,
        index = 0;

  @override
  bool operator ==(Object other) =>
      other is LineupSlot && other.area == area && other.index == index;

  @override
  int get hashCode => Object.hash(area, index);
}

/// A session line-up: two teams of six on a full court plus a sideline bench
/// with one sub slot for every attendee beyond the twelve on court (20
/// players → 8 subs, 12 or fewer → none). Pure and immutable — every edit
/// returns a new [Lineup].
class Lineup {
  static const teamSize = 6;

  /// Upper bound on stored bench slots, so a malformed doc can't balloon.
  static const maxBench = 100;

  /// Sub slots for a session with [attendees] players.
  static int benchSlotsFor(int attendees) =>
      (attendees - teamSize * 2).clamp(0, maxBench);

  /// Player uid per Team A position (index 0 = position 1), null when empty.
  final List<String?> teamA;

  /// Player uid per Team B position (index 0 = position 1), null when empty.
  final List<String?> teamB;

  /// Player uid per sideline slot, null when empty. Its length follows the
  /// attendee count — see [benchSlotsFor] and [reconcile].
  final List<String?> bench;

  const Lineup._(this.teamA, this.teamB, this.bench);

  /// No one placed and no bench slots; [reconcile] sizes the bench.
  factory Lineup.empty() => Lineup._(
        List<String?>.filled(teamSize, null),
        List<String?>.filled(teamSize, null),
        const [],
      );

  /// Reads the stored shape (`teamA`/`teamB`/`bench` uid lists, null for an
  /// empty spot). Team lists of the wrong length are padded or trimmed so a
  /// malformed doc can never break the court layout; the bench keeps its
  /// stored length (capped) and is resized by [reconcile].
  factory Lineup.fromMap(Map<String, dynamic> data) {
    List<String?> read(String key, int size) {
      final raw = data[key];
      final list = raw is List ? raw : const [];
      return [
        for (var i = 0; i < size; i++)
          i < list.length && list[i] is String && (list[i] as String).isNotEmpty
              ? list[i] as String
              : null,
      ];
    }

    return Lineup._(
      read('teamA', teamSize),
      read('teamB', teamSize),
      read('bench', min(data['bench'] is List ? (data['bench'] as List).length : 0, maxBench)),
    );
  }

  /// The stored shape read by [Lineup.fromMap]; persistence metadata
  /// (updatedAt/updatedBy) is added by the datasource.
  Map<String, dynamic> toMap() => {
        'teamA': teamA,
        'teamB': teamB,
        'bench': bench,
      };

  bool get isEmpty => [...teamA, ...teamB, ...bench].every((u) => u == null);

  List<String?> _list(LineupArea area) => switch (area) {
        LineupArea.teamA => teamA,
        LineupArea.teamB => teamB,
        LineupArea.bench => bench,
        LineupArea.pool => const [],
      };

  String? at(LineupSlot slot) =>
      slot.area == LineupArea.pool ? null : _list(slot.area)[slot.index];

  /// The slot [uid] currently occupies, or the pool when unplaced.
  LineupSlot slotOf(String uid) {
    for (final area in const [
      LineupArea.teamA,
      LineupArea.teamB,
      LineupArea.bench,
    ]) {
      final i = _list(area).indexOf(uid);
      if (i != -1) return LineupSlot(area, i);
    }
    return const LineupSlot.pool();
  }

  bool _isPlaced(String uid) =>
      teamA.contains(uid) || teamB.contains(uid) || bench.contains(uid);

  /// Attendees not placed on either team or the bench, in attendee order.
  List<String> pool(List<String> attendeeIds) =>
      [for (final uid in attendeeIds) if (!_isPlaced(uid)) uid];

  /// Moves [uid] into [to]. If [to] is occupied, the occupant swaps into
  /// [uid]'s previous spot (or drops to the pool when [uid] came from there).
  Lineup move(String uid, LineupSlot to) {
    final from = slotOf(uid);
    if (from == to) return this;
    final next = {
      LineupArea.teamA: [...teamA],
      LineupArea.teamB: [...teamB],
      LineupArea.bench: [...bench],
    };

    void put(LineupSlot slot, String? value) {
      if (slot.area == LineupArea.pool) return;
      next[slot.area]![slot.index] = value;
    }

    final displaced = at(to);
    put(from, displaced);
    put(to, uid);
    return Lineup._(
      next[LineupArea.teamA]!,
      next[LineupArea.teamB]!,
      next[LineupArea.bench]!,
    );
  }

  /// Randomly places [attendeeIds]: six for Team A, the next six for Team B,
  /// everyone else on the bench (which has exactly one slot per extra player).
  static Lineup shuffle(List<String> attendeeIds, Random rng) {
    final ids = [...attendeeIds]..shuffle(rng);
    final result = Lineup._(
      List<String?>.filled(teamSize, null),
      List<String?>.filled(teamSize, null),
      List<String?>.filled(benchSlotsFor(attendeeIds.length), null),
    );
    final targets = [result.teamA, result.teamB, result.bench];
    var i = 0;
    for (final list in targets) {
      for (var j = 0; j < list.length && i < ids.length; j++, i++) {
        list[j] = ids[i];
      }
    }
    return result;
  }

  /// Drops anyone who is no longer an attendee (e.g. they left the session)
  /// and sizes the bench to [benchSlotsFor] the current attendee count.
  /// When the bench shrinks, subs in removed slots move up into free slots;
  /// any that still don't fit go back to the pool.
  Lineup reconcile(List<String> attendeeIds) {
    final keep = attendeeIds.toSet();
    final size = benchSlotsFor(attendeeIds.length);
    final placed = [...teamA, ...teamB, ...bench];
    if (bench.length == size &&
        placed.every((u) => u == null || keep.contains(u))) {
      return this;
    }
    List<String?> filter(List<String?> list) =>
        [for (final u in list) u != null && keep.contains(u) ? u : null];

    final kept = filter(bench);
    final resized = [
      ...kept.take(size),
      for (var i = kept.length; i < size; i++) null,
    ];
    for (final uid in kept.skip(size)) {
      if (uid == null) continue;
      final free = resized.indexOf(null);
      if (free == -1) break;
      resized[free] = uid;
    }
    return Lineup._(filter(teamA), filter(teamB), resized);
  }
}
