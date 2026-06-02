import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';

// All groups user is a member of (raw, unfiltered)
final _allGroupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('groups')
      .where('memberIds', arrayContains: uid)
      .snapshots()
      .map((snap) => snap.docs.map(GroupModel.fromDoc).toList());
});

// Active groups (not archived by current user) — shown on main Groups screen
final groupsProvider = Provider<AsyncValue<List<GroupModel>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final all = ref.watch(_allGroupsProvider);
  return all.whenData((groups) =>
      groups.where((g) => !g.archivedBy.contains(uid)).toList());
});

// Archived groups (shown in Profile)
final archivedGroupsProvider =
    Provider<AsyncValue<List<GroupModel>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final all = ref.watch(_allGroupsProvider);
  return all.whenData((groups) =>
      groups.where((g) => g.archivedBy.contains(uid)).toList());
});

// Single group stream (used by group detail to get live updates)
final groupStreamProvider =
    StreamProvider.family<GroupModel, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .where((doc) => doc.exists)
      .map(GroupModel.fromDoc);
});

class GroupsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<GroupModel> createGroup(
    String name, {
    String? emoji,
    int? tripLength,
    int? tripLengthTolerance,
    DateTime? windowStart,
    DateTime? windowEnd,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final code = _generateCode();
    final doc = FirebaseFirestore.instance.collection('groups').doc();
    final group = GroupModel(
      id: doc.id,
      name: name.trim(),
      emoji: emoji,
      createdBy: uid,
      createdAt: DateTime.now(),
      inviteCode: code,
      memberIds: [uid],
      tripLength: tripLength,
      tripLengthTolerance: tripLengthTolerance,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    await doc.set(group.toMap());

    // Log activity: created
    await doc.collection('activity').add({
      'uid': uid,
      'action': 'created',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return group;
  }

  Future<GroupModel> joinGroup(String rawCode) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final code = rawCode.trim().toUpperCase();

    final snap = await FirebaseFirestore.instance
        .collection('groups')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw Exception('No group found with that code.');

    final doc = snap.docs.first;
    final group = GroupModel.fromDoc(doc);

    if (group.memberIds.contains(uid)) {
      throw Exception('You\'re already a member of this group.');
    }

    await doc.reference.update({
      'memberIds': FieldValue.arrayUnion([uid]),
    });

    // Log activity: joined
    await doc.reference.collection('activity').add({
      'uid': uid,
      'action': 'joined',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return GroupModel(
      id: group.id,
      name: group.name,
      emoji: group.emoji,
      createdBy: group.createdBy,
      createdAt: group.createdAt,
      inviteCode: group.inviteCode,
      memberIds: [...group.memberIds, uid],
      archivedBy: group.archivedBy,
    );
  }

  Future<void> updateGroup(
    String groupId, {
    required String name,
    String? emoji,
    int? tripLength,
    int? tripLengthTolerance,
    DateTime? windowStart,
    DateTime? windowEnd,
  }) async {
    await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
      'name': name.trim(),
      'emoji': emoji,
      'tripLength': tripLength,
      'tripLengthTolerance': tripLengthTolerance,
      'windowStart':
          windowStart != null ? Timestamp.fromDate(windowStart) : null,
      'windowEnd':
          windowEnd != null ? Timestamp.fromDate(windowEnd) : null,
    });
  }

  /// Set per-group availability override for a specific date.
  /// Pass DateStatus.none to clear the override (use profile setting).
  Future<void> setMyOverrideInGroup(
      String groupId, DateTime date, /* DateStatus */ String status) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final docRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('availabilities')
        .doc(uid);

    // Always remove from all arrays first
    await docRef.set({
      'availableDates': FieldValue.arrayRemove([dateStr]),
      'likelyDates': FieldValue.arrayRemove([dateStr]),
      'maybeDates': FieldValue.arrayRemove([dateStr]),
      'unavailableDates': FieldValue.arrayRemove([dateStr]),
    }, SetOptions(merge: true));

    if (status == 'none') return;
    final field = switch (status) {
      'available' => 'availableDates',
      'likely' => 'likelyDates',
      'maybe' => 'maybeDates',
      'unavailable' => 'unavailableDates',
      _ => null,
    };
    if (field != null) {
      await docRef.set(
          {field: FieldValue.arrayUnion([dateStr])},
          SetOptions(merge: true));
    }
  }

  /// Sets the current user's name within a specific group.
  /// Pass null to clear (fall back to nickname/displayName).
  Future<void> setMyNameInGroup(String groupId, String? name) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    if (name == null || name.trim().isEmpty) {
      await ref.update({'memberNames.$uid': FieldValue.delete()});
    } else {
      await ref.set({
        'memberNames': {uid: name.trim()},
      }, SetOptions(merge: true));
    }
  }

  Future<void> archiveGroup(String groupId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
      'archivedBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> unarchiveGroup(String groupId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
      'archivedBy': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    await ref.update({
      'memberIds': FieldValue.arrayRemove([uid]),
    });
    await ref.collection('activity').add({
      'uid': uid,
      'action': 'left',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle the current user's confirmation for a date in a group.
  /// If user is already in confirmations[date] → removes them.
  /// Otherwise → adds them.
  Future<void> toggleConfirmation(String groupId, DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final ref =
        FirebaseFirestore.instance.collection('groups').doc(groupId);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final raw = (data['confirmations'] as Map?) ?? {};
    final current = List<String>.from((raw[dateStr] as List?) ?? []);
    if (current.contains(uid)) {
      await ref.update({
        'confirmations.$dateStr': FieldValue.arrayRemove([uid]),
      });
      await ref.collection('activity').add({
        'uid': uid,
        'action': 'unconfirmed',
        'date': dateStr,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'confirmations': {
          dateStr: FieldValue.arrayUnion([uid]),
        }
      }, SetOptions(merge: true));
      await ref.collection('activity').add({
        'uid': uid,
        'action': 'confirmed',
        'date': dateStr,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteGroup(String groupId) async {
    // Delete activity subcollection first
    final activitySnap = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('activity')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in activitySnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(
        FirebaseFirestore.instance.collection('groups').doc(groupId));
    await batch.commit();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

final groupsNotifierProvider =
    AsyncNotifierProvider<GroupsNotifier, void>(GroupsNotifier.new);
