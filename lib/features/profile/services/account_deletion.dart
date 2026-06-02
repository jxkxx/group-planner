import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result of an account-deletion attempt.
sealed class DeletionResult {
  const DeletionResult();
}

class DeletionSuccess extends DeletionResult {
  const DeletionSuccess();
}

class DeletionNeedsReauth extends DeletionResult {
  const DeletionNeedsReauth();
}

class DeletionError extends DeletionResult {
  final String message;
  const DeletionError(this.message);
}

/// Deletes the currently signed-in user's account and all associated data.
///
/// Steps:
/// 1. Find all groups the user is a member of.
/// 2. For each group:
///    a. Remove user from `memberIds`.
///    b. If the user was the creator AND other members remain → transfer to oldest member.
///    c. If the user was the only member → delete the group (and its subcollections).
///    d. Delete user's `availabilities/{uid}` override doc.
/// 3. Delete `users/{uid}` doc.
/// 4. Delete the Firebase Auth account.
///
/// If Firebase Auth requires recent login, returns [DeletionNeedsReauth].
Future<DeletionResult> deleteAccountAndData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const DeletionError('Not signed in.');
  final uid = user.uid;
  final db = FirebaseFirestore.instance;

  try {
    // 1. Find all groups I'm a member of
    final groupsSnap = await db
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .get();

    for (final groupDoc in groupsSnap.docs) {
      final groupId = groupDoc.id;
      final data = groupDoc.data();
      final memberIds = List<String>.from(data['memberIds'] as List? ?? []);
      final createdBy = data['createdBy'] as String?;
      final otherMembers = memberIds.where((m) => m != uid).toList();

      // 2d. Delete my per-group availability override (if any)
      await db
          .collection('groups')
          .doc(groupId)
          .collection('availabilities')
          .doc(uid)
          .delete()
          .catchError((_) {}); // Ignore "not exists"

      if (otherMembers.isEmpty) {
        // 2c. I'm the only member — delete group + its subcollections
        await _deleteGroupCompletely(db, groupId);
      } else if (createdBy == uid) {
        // 2b. I'm the creator but others remain — transfer ownership
        await groupDoc.reference.update({
          'memberIds': FieldValue.arrayRemove([uid]),
          'createdBy': otherMembers.first,
        });
      } else {
        // 2a. Just remove me from memberIds
        await groupDoc.reference.update({
          'memberIds': FieldValue.arrayRemove([uid]),
        });
      }
    }

    // 3. Delete my user doc
    await db.collection('users').doc(uid).delete().catchError((_) {});

    // 4. Delete the Firebase Auth account
    await user.delete();

    return const DeletionSuccess();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      return const DeletionNeedsReauth();
    }
    return DeletionError('Auth error: ${e.message ?? e.code}');
  } catch (e) {
    return DeletionError('Error: $e');
  }
}

/// Delete a group doc + its activity + availabilities subcollections.
Future<void> _deleteGroupCompletely(
    FirebaseFirestore db, String groupId) async {
  final groupRef = db.collection('groups').doc(groupId);

  // Delete activity subcollection in batches
  final activitySnap = await groupRef.collection('activity').get();
  for (final doc in activitySnap.docs) {
    await doc.reference.delete().catchError((_) {});
  }

  // Delete availabilities subcollection
  final availSnap = await groupRef.collection('availabilities').get();
  for (final doc in availSnap.docs) {
    await doc.reference.delete().catchError((_) {});
  }

  // Delete the group itself
  await groupRef.delete();
}
