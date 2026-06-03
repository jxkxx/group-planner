import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../groups/providers/activity_provider.dart';

// ─── Status enums ────────────────────────────────────────────────────────────

/// Group-level status — keeps 4 statuses (members opt-in per group).
enum DateStatus {
  none,
  available,    // green — "I can make it"
  likely,       // light green — "Probably yes"
  maybe,        // amber — "Not sure"
  unavailable,  // red — "Can't make it"
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

/// Personal calendar — only unavailable + maybe-unavailable.
/// Logic: "I'm marking when I CAN'T travel. Default = open."
enum PersonalDateStatus {
  none,
  maybeUnavailable, // amber — "probably can't make it"
  unavailable,      // red — "definitely can't"
}

extension PersonalDateStatusLabel on PersonalDateStatus {
  String get label => switch (this) {
        PersonalDateStatus.unavailable => 'Unavailable',
        PersonalDateStatus.maybeUnavailable => 'Maybe Unavailable',
        PersonalDateStatus.none => 'None',
      };
  String get subtitle => switch (this) {
        PersonalDateStatus.unavailable => "I can't make it",
        PersonalDateStatus.maybeUnavailable => "I probably can't make it",
        PersonalDateStatus.none => '',
      };
}

// ─── Data model ──────────────────────────────────────────────────────────────

/// Aggregate of all the user's marked dates.
/// Fields kept for backward-compat with groups; personal screen uses only
/// `unavailable` and `maybeUnavailable`.
class AvailabilityData {
  final Set<DateTime> available;
  final Set<DateTime> likely;
  final Set<DateTime> maybe;
  final Set<DateTime> unavailable;
  final Set<DateTime> maybeUnavailable;

  const AvailabilityData({
    required this.available,
    required this.likely,
    required this.maybe,
    required this.unavailable,
    required this.maybeUnavailable,
  });

  DateStatus statusOf(DateTime day) {
    if (available.contains(day)) return DateStatus.available;
    if (likely.contains(day)) return DateStatus.likely;
    if (maybe.contains(day)) return DateStatus.maybe;
    if (unavailable.contains(day)) return DateStatus.unavailable;
    return DateStatus.none;
  }

  PersonalDateStatus personalStatusOf(DateTime day) {
    if (unavailable.contains(day)) return PersonalDateStatus.unavailable;
    if (maybeUnavailable.contains(day)) {
      return PersonalDateStatus.maybeUnavailable;
    }
    return PersonalDateStatus.none;
  }
}

// ─── Stream providers ───────────────────────────────────────────────────────

final availabilityDataProvider = StreamProvider<AvailabilityData>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(const AvailabilityData(
        available: {},
        likely: {},
        maybe: {},
        unavailable: {},
        maybeUnavailable: {}));
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
      maybeUnavailable: _parseDatesField(d['maybeUnavailableDates']),
    );
  });
});

// Backward-compat for any legacy callers
final availableDatesProvider = StreamProvider<Set<DateTime>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value({});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => _parseDatesField(doc.data()?['availableDates']));
});

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AvailabilityNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Personal calendar: set unavailable / maybe-unavailable / clear.
  Future<void> setPersonalStatus(
      DateTime day, PersonalDateStatus status) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dateStr = formatDate(day);
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(uid);

    // Clear from ALL personal fields — legacy + new — to keep data clean
    // after the paradigm shift to unavailability-only.
    await docRef.set({
      'unavailableDates': FieldValue.arrayRemove([dateStr]),
      'maybeUnavailableDates': FieldValue.arrayRemove([dateStr]),
      'availableDates': FieldValue.arrayRemove([dateStr]),
      'likelyDates': FieldValue.arrayRemove([dateStr]),
      'maybeDates': FieldValue.arrayRemove([dateStr]),
    }, SetOptions(merge: true));

    if (status == PersonalDateStatus.none) {
      writeAvailabilityActivity('removed', day).catchError((_) {});
      return;
    }

    final field = status == PersonalDateStatus.unavailable
        ? 'unavailableDates'
        : 'maybeUnavailableDates';
    await docRef.set(
        {field: FieldValue.arrayUnion([dateStr])},
        SetOptions(merge: true));

    final action = status == PersonalDateStatus.unavailable
        ? 'unavailable'
        : 'maybe_unavailable';
    writeAvailabilityActivity(action, day).catchError((_) {});
  }

  /// Group-level (used in group detail). Writes one of 4 statuses to the
  /// per-group availabilities subcollection.
  Future<void> setDateStatus(DateTime day, DateStatus status) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dateStr = formatDate(day);
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(uid);

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

    final action = status == DateStatus.none ? 'removed' : status.name;
    writeAvailabilityActivity(action, day).catchError((_) {});
  }

  // Backward compat — no-op for any leftover callers.
  Future<void> toggleDate(DateTime day) async {}
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
