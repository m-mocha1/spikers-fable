import 'package:cloud_firestore/cloud_firestore.dart';

/// A shared, reusable set of players for building custom (members-only)
/// sessions. Stored in the top-level `player_groups` collection so the whole
/// coaching staff draws from one team library — any coach can apply, edit, or
/// delete any group. [createdBy] records the coach who first saved it.
class PlayerGroup {
  final String id;
  final String name;
  final List<String> memberIds;

  /// Uid of the coach who created the group (audit only — every coach may edit
  /// or delete any group). Empty for legacy docs written before this field.
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlayerGroup({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  int get memberCount => memberIds.length;

  factory PlayerGroup.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final created = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return PlayerGroup(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      memberIds: ((d['memberIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      createdBy: (d['createdBy'] ?? '') as String,
      createdAt: created,
      // Older docs may predate updatedAt; fall back to createdAt.
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? created,
    );
  }

  /// Payload for a brand-new group; Firestore assigns the id. Stamps
  /// [createdBy], which the security rule requires to equal the caller.
  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'memberIds': memberIds,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// Partial payload for editing an existing group (rename and/or new roster),
  /// bumping updatedAt without touching createdBy/createdAt.
  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'memberIds': memberIds,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
