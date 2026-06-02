import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String? emoji;
  final String createdBy;
  final DateTime createdAt;
  final String inviteCode;
  final List<String> memberIds;
  final List<String> archivedBy;

  // Optional trip constraints
  final int? tripLength;          // base length in days
  final int? tripLengthTolerance; // ± days (allows length in [base-tol, base+tol])
  final DateTime? windowStart;    // inclusive
  final DateTime? windowEnd;      // inclusive

  // Per-group name override: uid -> display name
  final Map<String, String> memberNames;

  const GroupModel({
    required this.id,
    required this.name,
    this.emoji,
    required this.createdBy,
    required this.createdAt,
    required this.inviteCode,
    required this.memberIds,
    this.archivedBy = const [],
    this.tripLength,
    this.tripLengthTolerance,
    this.windowStart,
    this.windowEnd,
    this.memberNames = const {},
  });

  factory GroupModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] as String,
      emoji: data['emoji'] as String?,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      inviteCode: data['inviteCode'] as String,
      memberIds: List<String>.from(data['memberIds'] as List),
      archivedBy: List<String>.from(data['archivedBy'] as List? ?? []),
      tripLength: (data['tripLength'] as num?)?.toInt(),
      tripLengthTolerance: (data['tripLengthTolerance'] as num?)?.toInt(),
      windowStart: (data['windowStart'] as Timestamp?)?.toDate(),
      windowEnd: (data['windowEnd'] as Timestamp?)?.toDate(),
      memberNames: Map<String, String>.from(
          (data['memberNames'] as Map?) ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (emoji != null) 'emoji': emoji,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'inviteCode': inviteCode,
        'memberIds': memberIds,
        'archivedBy': archivedBy,
        if (tripLength != null) 'tripLength': tripLength,
        if (tripLengthTolerance != null)
          'tripLengthTolerance': tripLengthTolerance,
        if (windowStart != null)
          'windowStart': Timestamp.fromDate(windowStart!),
        if (windowEnd != null) 'windowEnd': Timestamp.fromDate(windowEnd!),
      };
}

/// Formats trip length as "N days / N-1 nights" or "1 day".
String formatTripLength(int? days) {
  if (days == null || days < 1) return '';
  if (days == 1) return '1 day';
  return '$days days / ${days - 1} ${days - 1 == 1 ? 'night' : 'nights'}';
}
