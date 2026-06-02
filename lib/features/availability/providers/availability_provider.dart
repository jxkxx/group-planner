import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../groups/providers/activity_provider.dart';

// ─── Status enum ─────────────────────────────────────────────────────────────

enum DateStatus {
  none,
  available,    // solid green  — "I can make it"
  likely,       // light green  — "Probably yes"
  maybe,        // amber/orange — "Not sure yet"
  unavailable,  // solid red    — "Can't make it"
}

extension DateStatusLabel on DateStatus {
  String get label => switch (this) {
        DateStatus.available => 'Available',
        DateStatus.likely => 'Likely',
        DateStatus.maybe => 'Maybe',
        DateStatus.unavailable => 'Unavailable',
        DateStatus.none => 'None',
      };
}

// ─── Data model ───────────────────────────────────────────────────────────────

class AvailabilityData {
  final Set<DateTime> available;
  final Set<DateTime> likely;
  final Set<DateTime> maybe;
  final Set<DateTime> unavailable;

  const AvailabilityData({
    required this.available,
    required this.likely,
    required this.maybe,
    required this.unavailable,
  });

  DateStatus statusOf(DateTime day) {
    if (available.contains(day)) return DateStatus.available;
    if (likely.contains(day)) return DateStatus.likely;
    if (maybe.contains(day)) return DateStatus.maybe;
    if (unavailable.contains(day)) return DateStatus.unavailable;
    return DateStatus.none;
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final availabilityDataProvider = StreamProvider<AvailabilityData>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(AvailabilityData(
        available: {}, likely: {}, maybe: {}, unavailable: {}));
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
    final d = doc.data() ?? {};
    return AvailabilityData(
      available: _parseDatesField(d['availableDates']),
      likely: _parseDatesField(d['likelyDates']),
      maybe: _parseDatesField(d['maybeDates']),
      unavailable: _parseDatesField(d['unavailableDates']),
    );
  });
});

// Backward-compat: used by group detail for member data
final availableDatesProvider = StreamProvider<Set<DateTime>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value({});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) =>
          _parseDatesField(doc.data()?['availableDates']));
});

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AvailabilityNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setDateStatus(DateTime day, DateStatus status) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dateStr = formatDate(day);
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(uid);

    // Remove from all arrays, then add to the right one
    final Map<String, dynamic> update = {
      'availableDates': FieldValue.arrayRemove([dateStr]),
      'likelyDates': FieldValue.arrayRemove([dateStr]),
      'maybeDates': FieldValue.arrayRemove([dateStr]),
      'unavailableDates': FieldValue.arrayRemove([dateStr]),
    };
    await docRef.set(update, SetOptions(merge: true));

    if (status != DateStatus.none) {
      final field = switch (status) {
        DateStatus.available => 'availableDates',
        DateStatus.likely => 'likelyDates',
        DateStatus.maybe => 'maybeDates',
        DateStatus.unavailable => 'unavailableDates',
        DateStatus.none => '',
      };
      await docRef.set(
          {field: FieldValue.arrayUnion([dateStr])},
          SetOptions(merge: true));
    }

    // Write activity entries to all user's groups (fire-and-forget)
    final action = status == DateStatus.none ? 'removed' : status.name;
    writeAvailabilityActivity(action, day).catchError((_) {});
  }

  // Backward compat
  Future<void> toggleDate(DateTime day) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dateStr = formatDate(day);
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await docRef.get();
    final avail = List<String>.from(
        doc.data()?['availableDates'] as List? ?? []);
    if (avail.contains(dateStr)) {
      await docRef.set(
          {'availableDates': FieldValue.arrayRemove([dateStr])},
          SetOptions(merge: true));
    } else {
      await docRef.set(
          {'availableDates': FieldValue.arrayUnion([dateStr])},
          SetOptions(merge: true));
    }
  }
}

final availabilityNotifierProvider =
    AsyncNotifierProvider<AvailabilityNotifier, void>(
        AvailabilityNotifier.new);

// ─── Helpers ──────────────────────────────────────────────────────────────────

Set<DateTime> _parseDatesField(dynamic raw) {
  if (raw == null) return {};
  return List<String>.from(raw as List)
      .map(parseDate)
      .whereType<DateTime>()
      .toSet();
}

String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDate(String s) {
  try {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  } catch (_) {
    return null;
  }
}
