// Pure selection helpers for applying saved player groups to a custom-session
// member selection. Kept UI-free so the toggle/union logic is unit-testable.
//
// Highlight is tracked EXPLICITLY (the set of group ids the coach tapped on),
// never derived from the member set — otherwise a group whose members happen to
// be a subset of the current selection would falsely light up when a different,
// overlapping group is applied.
//
// [validUids] optionally restricts a group's members to players that still
// exist (a saved group can reference someone since removed). Pass `null` while
// the roster is still loading so a tap isn't silently dropped.

import 'entities/player_group_model.dart';

/// The still-valid members of [group] (all of them when [validUids] is null).
List<String> liveMembers(PlayerGroup group, Set<String>? validUids) {
  if (validUids == null) return group.memberIds;
  return group.memberIds.where(validUids.contains).toList();
}

/// The outcome of tapping a group chip: the new member selection and the new
/// set of explicitly-applied (highlighted) group ids.
typedef GroupToggle = ({Set<String> selected, Set<String> appliedGroupIds});

/// Toggles [group] against the current state. Applying adds its members and
/// marks it applied; un-applying removes its members and clears the mark — but
/// keeps any member still covered by *another applied group*, so overlapping
/// groups combine correctly. Returns new sets; inputs are not mutated.
GroupToggle toggleGroup({
  required PlayerGroup group,
  required List<PlayerGroup> allGroups,
  required Set<String> selected,
  required Set<String> appliedGroupIds,
  Set<String>? validUids,
}) {
  final live = liveMembers(group, validUids);
  final nextApplied = {...appliedGroupIds};
  final nextSelected = {...selected};

  if (appliedGroupIds.contains(group.id)) {
    nextApplied.remove(group.id);
    // Members still needed by another applied group must survive the removal.
    final keep = <String>{};
    for (final g in allGroups) {
      if (nextApplied.contains(g.id)) keep.addAll(liveMembers(g, validUids));
    }
    nextSelected.removeAll(live.where((m) => !keep.contains(m)));
  } else {
    nextApplied.add(group.id);
    nextSelected.addAll(live);
  }
  return (selected: nextSelected, appliedGroupIds: nextApplied);
}

/// Drops any applied-group id no longer fully covered by [selected] — e.g. after
/// the coach manually unchecks one of its members. Never *adds* ids, so a group
/// the coach never applied is never auto-highlighted just because the selection
/// happens to cover it. Call after any manual edit to the member set.
Set<String> reconcileAppliedGroups({
  required List<PlayerGroup> allGroups,
  required Set<String> appliedGroupIds,
  required Set<String> selected,
  Set<String>? validUids,
}) {
  final byId = {for (final g in allGroups) g.id: g};
  return appliedGroupIds.where((id) {
    final g = byId[id];
    if (g == null) return false;
    final live = liveMembers(g, validUids);
    return live.isNotEmpty && live.every(selected.contains);
  }).toSet();
}
