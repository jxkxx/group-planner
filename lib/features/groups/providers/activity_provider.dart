import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityEntry {
  final String id;
  final String uid;
  final String action; // 'created' | 'joined' | 'left' | 'available' | 'likely' | 'maybe' | 'unavailable' | 'removed'
  final String? date; // formatted yyyy-mm-dd for date-related actions
  final DateTime? timestamp;

  ActivityEntry({
    required this.id,
    required this.uid,
    required this.action,
    this.date,
    this.timestamp,
  });

  factory ActivityEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityEntry(
      id: doc.id,
      uid: data['uid'] as String,
      action: data['action'] as String,
      date: data['date'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}

// Stream activity entries for a group (latest first, limited to 50)
final groupActivityProvider =
    StreamProvider.family<List<ActivityEntry>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('activity')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(ActivityEntry.fromDoc).toList());
});

/// Write an availability-change activity entry to all groups the user is in.
Future<void> writeAvailabilityActivity(
    String action, DateTime date) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final groupsSnap = await FirebaseFirestore.instance
      .collection('groups')
      .where('memberIds', arrayContains: uid)
      .get();

  if (groupsSnap.docs.isEmpty) return;

  final dateStr =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  final batch = FirebaseFirestore.instance.batch();
  for (final groupDoc in groupsSnap.docs) {
    final activityRef = groupDoc.reference.collection('activity').doc();
    batch.set(activityRef, {
      'uid': uid,
      'action': action,
      'date': dateStr,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}
