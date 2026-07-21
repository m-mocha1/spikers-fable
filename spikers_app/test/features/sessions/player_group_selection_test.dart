import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/sessions/domain/entities/player_group_model.dart';
import 'package:spikers_app/features/sessions/domain/player_group_selection.dart';

PlayerGroup _group(String id, List<String> members) => PlayerGroup(
      id: id,
      name: id,
      memberIds: members,
      createdBy: 'c1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('toggleGroup', () {
    test('applying adds members and marks the group applied', () {
      final a = _group('a', ['p1', 'p2']);
      final r = toggleGroup(
        group: a,
        allGroups: [a],
        selected: {'x'},
        appliedGroupIds: {},
      );
      expect(r.selected, {'x', 'p1', 'p2'});
      expect(r.appliedGroupIds, {'a'});
    });

    test('un-applying removes members and clears the mark', () {
      final a = _group('a', ['p1', 'p2']);
      final r = toggleGroup(
        group: a,
        allGroups: [a],
        selected: {'p1', 'p2', 'x'},
        appliedGroupIds: {'a'},
      );
      expect(r.selected, {'x'});
      expect(r.appliedGroupIds, isEmpty);
    });

    test('un-applying keeps members still covered by another applied group', () {
      // a = p1,p2,p3 ; b = p3,p4 ; both applied. Un-apply a: p3 survives (b).
      final a = _group('a', ['p1', 'p2', 'p3']);
      final b = _group('b', ['p3', 'p4']);
      final r = toggleGroup(
        group: a,
        allGroups: [a, b],
        selected: {'p1', 'p2', 'p3', 'p4'},
        appliedGroupIds: {'a', 'b'},
      );
      expect(r.selected, {'p3', 'p4'});
      expect(r.appliedGroupIds, {'b'});
    });

    test('applying a shared player does not mark the other group applied', () {
      // The reported bug: b ⊆ what a selects, but only a was tapped, so only
      // a is highlighted.
      final a = _group('a', ['p1', 'p2']);
      final b = _group('b', ['p1']); // subset of a's members
      final r = toggleGroup(
        group: a,
        allGroups: [a, b],
        selected: {},
        appliedGroupIds: {},
      );
      expect(r.selected, {'p1', 'p2'});
      expect(r.appliedGroupIds, {'a'}); // NOT {'a','b'}
    });

    test('does not mutate the input sets', () {
      final a = _group('a', ['p2']);
      final selected = {'p1'};
      final applied = <String>{};
      toggleGroup(
          group: a, allGroups: [a], selected: selected, appliedGroupIds: applied);
      expect(selected, {'p1'});
      expect(applied, isEmpty);
    });

    test('applies only live members when validUids is given', () {
      final a = _group('a', ['p1', 'ghost']);
      final r = toggleGroup(
        group: a,
        allGroups: [a],
        selected: {},
        appliedGroupIds: {},
        validUids: {'p1'},
      );
      expect(r.selected, {'p1'});
      expect(r.appliedGroupIds, {'a'});
    });
  });

  group('reconcileAppliedGroups', () {
    test('drops a group no longer fully selected (manual uncheck)', () {
      final a = _group('a', ['p1', 'p2']);
      final result = reconcileAppliedGroups(
        allGroups: [a],
        appliedGroupIds: {'a'},
        selected: {'p1'}, // p2 was unchecked
      );
      expect(result, isEmpty);
    });

    test('keeps a group that is still fully selected', () {
      final a = _group('a', ['p1', 'p2']);
      final result = reconcileAppliedGroups(
        allGroups: [a],
        appliedGroupIds: {'a'},
        selected: {'p1', 'p2', 'x'},
      );
      expect(result, {'a'});
    });

    test('never adds a group that was not already applied', () {
      // Selection fully covers b, but b was never applied — must stay off.
      final b = _group('b', ['p1']);
      final result = reconcileAppliedGroups(
        allGroups: [b],
        appliedGroupIds: {},
        selected: {'p1'},
      );
      expect(result, isEmpty);
    });

    test('drops an applied group that was deleted', () {
      final result = reconcileAppliedGroups(
        allGroups: const [],
        appliedGroupIds: {'gone'},
        selected: {'p1'},
      );
      expect(result, isEmpty);
    });
  });
}
