import 'package:flutter_test/flutter_test.dart';

import 'package:spikers_app/features/players/domain/entities/player_summary.dart';
import 'package:spikers_app/features/players/presentation/widgets/player_sort_chip.dart';

/// The roster sort has to keep the datasource's A–Z order inside each
/// membership group — `List.sort` is not stable, so the name tiebreak is what
/// actually holds that promise. These guard it without a widget or Firestore.
void main() {
  PlayerSummary player(
    String name, {
    DateTime? paidUntil,
    bool lifetime = false,
  }) =>
      PlayerSummary(
        uid: name,
        name: name,
        gender: 'male',
        photoUrl: '',
        dateOfBirth: null,
        createdAt: null,
        attendanceCount: 0,
        paidUntil: paidUntil,
        lifetimeMember: lifetime,
        injured: false,
      );

  final future = DateTime.now().add(const Duration(days: 30));
  final past = DateTime.now().subtract(const Duration(days: 5));

  // Interleaved actives and inactives, already A–Z. More than 8 entries so
  // `List.sort` takes the quicksort path instead of the stable insertion sort
  // it uses for tiny lists — that is the case the name tiebreak exists for.
  List<PlayerSummary> roster() => [
        player('Adam', paidUntil: future),
        player('Basel', paidUntil: past),
        player('Camil'),
        player('Dana', lifetime: true),
        player('Elias', paidUntil: future),
        player('Farah'),
        player('Ghaith', paidUntil: past),
        player('Hadi', lifetime: true),
        player('Iyad', paidUntil: future),
        player('Jad'),
      ];

  List<String> names(List<PlayerSummary> players) =>
      players.map((p) => p.name).toList();

  test('the default sort leaves the datasource order untouched', () {
    final input = roster();
    expect(identical(PlayerSort.name.apply(input), input), isTrue);
  });

  test('activeFirst lifts paid and lifetime members, A–Z within each group',
      () {
    expect(
      names(PlayerSort.activeFirst.apply(roster())),
      ['Adam', 'Dana', 'Elias', 'Hadi', 'Iyad', 'Basel', 'Camil', 'Farah',
        'Ghaith', 'Jad'],
    );
  });

  test('inactiveFirst lifts expired and never-paid members', () {
    expect(
      names(PlayerSort.inactiveFirst.apply(roster())),
      ['Basel', 'Camil', 'Farah', 'Ghaith', 'Jad', 'Adam', 'Dana', 'Elias',
        'Hadi', 'Iyad'],
    );
  });

  test('sorting does not mutate the source list', () {
    final input = roster();
    PlayerSort.activeFirst.apply(input);
    expect(names(input).first, 'Adam');
    expect(names(input)[1], 'Basel');
  });

  test('the chip cycles off → active → inactive → off', () {
    expect(PlayerSort.name.next, PlayerSort.activeFirst);
    expect(PlayerSort.activeFirst.next, PlayerSort.inactiveFirst);
    expect(PlayerSort.inactiveFirst.next, PlayerSort.name);

    expect(PlayerSort.name.isApplied, isFalse);
    expect(PlayerSort.activeFirst.isApplied, isTrue);
    expect(PlayerSort.inactiveFirst.isApplied, isTrue);
  });
}
