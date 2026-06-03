import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/group_model.dart';
import '../providers/groups_provider.dart';
import '../providers/activity_provider.dart';
import '../../availability/providers/availability_provider.dart';
import '../../../core/theme_provider.dart';
import 'edit_group_screen.dart';
import 'group_details_screen.dart';
import '../../../core/design_tokens.dart';

// ─── Member data ─────────────────────────────────────────────────────────────

class MemberData {
  final String uid;
  final String name;
  final Set<DateTime> available;
  final Set<DateTime> likely;
  final Set<DateTime> maybe;
  final Set<DateTime> unavailable;
  // Dates that have a per-group override (visual indicator).
  final Set<DateTime> overridden;
  // Raw global status (without overrides applied), used for warning UI.
  final Map<DateTime, String> globalStatus;

  const MemberData({
    required this.uid,
    required this.name,
    required this.available,
    required this.likely,
    required this.maybe,
    required this.unavailable,
    this.overridden = const {},
    this.globalStatus = const {},
  });

  double scoreFor(DateTime d) {
    if (available.contains(d)) return 1.0;
    if (likely.contains(d)) return 0.5;
    if (maybe.contains(d)) return 0.1;
    return 0.0;
  }

  String? statusFor(DateTime d) {
    if (available.contains(d)) return 'available';
    if (likely.contains(d)) return 'likely';
    if (maybe.contains(d)) return 'maybe';
    if (unavailable.contains(d)) return 'unavailable';
    return null;
  }
}

// Stream of per-group overrides for ALL members of the group
final groupOverridesProvider = StreamProvider.family<
    Map<String, _OverrideData>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('availabilities')
      .snapshots()
      .map((snap) {
    final result = <String, _OverrideData>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      result[doc.id] = _OverrideData(
        available: _parseDates(d['availableDates']),
        likely: _parseDates(d['likelyDates']),
        maybe: _parseDates(d['maybeDates']),
        unavailable: _parseDates(d['unavailableDates']),
      );
    }
    return result;
  });
});

class _OverrideData {
  final Set<DateTime> available;
  final Set<DateTime> likely;
  final Set<DateTime> maybe;
  final Set<DateTime> unavailable;
  const _OverrideData({
    required this.available,
    required this.likely,
    required this.maybe,
    required this.unavailable,
  });

  Set<DateTime> get allDates =>
      {...available, ...likely, ...maybe, ...unavailable};
}

final _groupMembersProvider =
    StreamProvider.family<List<MemberData>, List<String>>(
        (ref, memberIds) {
  if (memberIds.isEmpty) return Stream.value([]);

  final streams = memberIds.map((uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? {};
      // Priority: nickname > displayName > "Member"
      final nick = (data['nickname'] as String?)?.trim();
      final display = (data['displayName'] as String?)?.trim();
      final name = (nick != null && nick.isNotEmpty)
          ? nick
          : (display != null && display.isNotEmpty ? display : 'Member');
      // Personal calendar sync (new paradigm — personal is unavailability-only):
      // - personal `unavailableDates` → group sees as Unavailable
      // - personal `maybeUnavailableDates` → group sees as Maybe
      // - Legacy fields (`availableDates`/`likelyDates`/`maybeDates`) are
      //   intentionally IGNORED here. Available/Likely/Maybe come only from
      //   the per-group override doc (`groups/{gid}/availabilities/{uid}`).
      return MemberData(
        uid: uid,
        name: name,
        available: {}, // never from personal — only from group override
        likely: {},
        maybe: _parseDates(data['maybeUnavailableDates']),
        unavailable: _parseDates(data['unavailableDates']),
      );
    });
  }).toList();

  if (streams.length == 1) return streams.first.map((m) => [m]);

  return streams.fold<Stream<List<MemberData>>>(
    Stream.value([]),
    (combined, memberStream) => combined.asyncMap((list) async {
      final member = await memberStream.first;
      return [...list, member];
    }),
  );
});

final _groupSettingsProvider =
    StreamProvider.family<bool, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      // Default to true so personal-calendar unavailable dates are visible
      // immediately without requiring a toggle flip.
      .map((doc) => (doc.data()?['showUnavailableDates'] as bool?) ?? true);
});

Set<DateTime> _parseDates(dynamic raw) {
  if (raw == null) return {};
  return List<String>.from(raw as List)
      .map(_parseDate)
      .whereType<DateTime>()
      .toSet();
}

DateTime? _parseDate(String s) {
  try {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  } catch (_) {
    return null;
  }
}

// Stable color per name (used in calendar dot overlays & member avatars)
const _avatarPalette = [
  Color(0xFF5C6BC0), AppColors.available, AppColors.danger,
  AppColors.accent, AppColors.info, AppColors.purple,
  AppColors.likely, AppColors.maybe, Color(0xFF7E57C2),
];
Color _colorFor(String key) {
  if (key.isEmpty) return _avatarPalette[0];
  return _avatarPalette[key.codeUnitAt(0) % _avatarPalette.length];
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.group});
  final GroupModel group;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Invite code copied!'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _openMenu(GroupModel group) async {
    final members =
        ref.read(_groupMembersProvider(group.memberIds)).value ?? [];
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = group.createdBy == uid;
    final isArchived = group.archivedBy.contains(uid);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20)),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (isCreator)
              _MenuItem(
                icon: Icons.edit_outlined,
                color: cs.primary,
                label: 'Edit Group',
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            _MenuItem(
              icon: Icons.bar_chart_outlined,
              color: AppColors.info,
              label: 'Details',
              onTap: () => Navigator.pop(context, 'details'),
            ),
            _MenuItem(
              icon: isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              color: AppColors.accent,
              label: isArchived ? 'Unarchive' : 'Archive',
              onTap: () => Navigator.pop(context, 'archive'),
            ),
            if (!isCreator)
              _MenuItem(
                icon: Icons.logout,
                color: AppColors.accent,
                label: 'Leave Group',
                onTap: () => Navigator.pop(context, 'leave'),
              ),
            if (isCreator)
              _MenuItem(
                icon: Icons.delete_outline,
                color: AppColors.danger,
                label: 'Delete Group',
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );

    if (action == null || !mounted) return;

    final notifier = ref.read(groupsNotifierProvider.notifier);

    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EditGroupScreen(group: group)),
        );
      case 'details':
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => GroupDetailsBreakdownScreen(
                  group: group, members: members)),
        );
      case 'archive':
        if (isArchived) {
          await notifier.unarchiveGroup(group.id);
        } else {
          await notifier.archiveGroup(group.id);
          if (mounted) Navigator.pop(context);
        }
      case 'leave':
        final confirmed = await _confirm(
            title: 'Leave group?',
            message: 'You won\'t be a member anymore.',
            confirmLabel: 'Leave');
        if (confirmed && mounted) {
          await notifier.leaveGroup(group.id);
          if (mounted) Navigator.pop(context);
        }
      case 'delete':
        final confirmed = await _confirm(
            title: 'Delete group?',
            message:
                'This will permanently delete the group for everyone. This cannot be undone.',
            confirmLabel: 'Delete',
            destructive: true);
        if (confirmed && mounted) {
          await notifier.deleteGroup(group.id);
          if (mounted) Navigator.pop(context);
        }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: cs.onSurface)),
        content: Text(message,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  Text('Cancel', style: TextStyle(color: cs.primary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel,
                  style: TextStyle(
                      color: destructive
                          ? AppColors.danger
                          : cs.primary,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    // Live group stream so edits / archives update instantly
    final groupAsync = ref.watch(groupStreamProvider(widget.group.id));
    final cs = Theme.of(context).colorScheme;

    return groupAsync.when(
      loading: () => Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: AppBar(), body: Center(child: Text('Error: $e'))),
      data: (group) {
        final membersAsync =
            ref.watch(_groupMembersProvider(group.memberIds));
        final showUnavailAsync =
            ref.watch(_groupSettingsProvider(group.id));
        final showUnavail = showUnavailAsync.value ?? false;
        final startDay = ref.watch(startingDayOfWeekProvider);

        return Scaffold(
          appBar: AppBar(
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              if (group.emoji != null) ...[
                Text(group.emoji!, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(group.name)),
            ]),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () => _openMenu(group),
              ),
            ],
            bottom: TabBar(
              controller: _tab,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.7),
              indicatorColor: cs.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Calendar'),
                Tab(text: 'Members'),
                Tab(text: 'Activity'),
              ],
            ),
          ),
          body: membersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (rawMembers) {
              final overrides =
                  ref.watch(groupOverridesProvider(group.id)).value ?? {};

              // Apply per-group name + availability overrides
              final members = rawMembers.map((m) {
                final nameOverride = group.memberNames[m.uid];
                final name =
                    (nameOverride != null && nameOverride.trim().isNotEmpty)
                        ? nameOverride.trim()
                        : m.name;

                final ovr = overrides[m.uid];
                if (ovr == null) {
                  return MemberData(
                    uid: m.uid,
                    name: name,
                    available: m.available,
                    likely: m.likely,
                    maybe: m.maybe,
                    unavailable: m.unavailable,
                  );
                }

                // Merge: override dates win over global. Build globalStatus map.
                final overridden = ovr.allDates;
                final globalStatus = <DateTime, String>{};
                for (final d in m.available) globalStatus[d] = 'available';
                for (final d in m.likely) globalStatus[d] = 'likely';
                for (final d in m.maybe) globalStatus[d] = 'maybe';
                for (final d in m.unavailable) globalStatus[d] = 'unavailable';

                return MemberData(
                  uid: m.uid,
                  name: name,
                  available: m.available.difference(overridden)
                    ..addAll(ovr.available),
                  likely: m.likely.difference(overridden)..addAll(ovr.likely),
                  maybe: m.maybe.difference(overridden)..addAll(ovr.maybe),
                  unavailable: m.unavailable.difference(overridden)
                    ..addAll(ovr.unavailable),
                  overridden: overridden,
                  globalStatus: globalStatus,
                );
              }).toList();

              return TabBarView(
                controller: _tab,
                children: [
                  _DatesTab(
                    group: group,
                    members: members,
                    startDay: startDay,
                    showUnavail: showUnavail,
                  ),
                  _MembersTab(group: group, members: members),
                  _ActivityTab(group: group, members: members),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Menu item ────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600, color: cs.onSurface)),
      onTap: onTap,
    );
  }
}

// ─── DATES TAB ────────────────────────────────────────────────────────────────

class _DatesTab extends ConsumerStatefulWidget {
  const _DatesTab({
    required this.group,
    required this.members,
    required this.startDay,
    required this.showUnavail,
  });

  final GroupModel group;
  final List<MemberData> members;
  final StartingDayOfWeek startDay;
  final bool showUnavail;

  @override
  ConsumerState<_DatesTab> createState() => _DatesTabState();
}

class _DatesTabState extends ConsumerState<_DatesTab> {
  DateTime _focusedDay = DateTime.now();
  // What member-vote dots to show on the calendar. Default: just available.
  // Toggle in the "Show member votes" dropdown.
  Set<DateStatus> _visibleVoteTypes = {DateStatus.available};
  bool get _showAllVotes => _visibleVoteTypes.isNotEmpty;
  bool? _localShowUnavail;
  bool _lastSyncedUnavail = false;

  // ── Multi-select state
  bool _selectMode = false;
  final Set<DateTime> _selected = {};

  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime get _today => _norm(DateTime.now());

  void _enterSelectMode() {
    setState(() {
      _selectMode = true;
      _selected.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  Future<void> _applyBulkStatus() async {
    if (_selected.isEmpty) return;
    final cs = Theme.of(context).colorScheme;

    final result = await showModalBottomSheet<DateStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cs.surface, borderRadius: BorderRadius.circular(20)),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            Text('Apply to ${_selected.length} date${_selected.length == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            ...DateStatus.values.where((s) => s != DateStatus.none).map((s) {
              final c = _statusToColor(s);
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_statusToIcon(s), color: c, size: 20),
                ),
                title: Text(s.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: cs.onSurface)),
                onTap: () => Navigator.pop(context, s),
              );
            }),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline,
                    color: cs.onSurface.withValues(alpha: 0.5), size: 20),
              ),
              title: Text('Reset (use profile)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.6))),
              onTap: () => Navigator.pop(context, DateStatus.none),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );

    if (result == null || !mounted) return;

    final notifier = ref.read(groupsNotifierProvider.notifier);
    try {
      for (final d in _selected) {
        await notifier.setMyOverrideInGroup(
            widget.group.id, d, result == DateStatus.none ? 'none' : result.name);
      }
      if (mounted) _exitSelectMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  Color _statusToColor(DateStatus s) => switch (s) {
        DateStatus.available => const Color(0xFF26A69A),
        DateStatus.likely => const Color(0xFF66BB6A),
        DateStatus.maybe => const Color(0xFFFFB74D),
        DateStatus.unavailable => const Color(0xFFEF5350),
        DateStatus.none => Colors.transparent,
      };

  IconData _statusToIcon(DateStatus s) => switch (s) {
        DateStatus.available => Icons.check_circle_outline,
        DateStatus.likely => Icons.thumb_up_outlined,
        DateStatus.maybe => Icons.help_outline,
        DateStatus.unavailable => Icons.cancel_outlined,
        DateStatus.none => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.members.length;
    final scoreMap = _buildScoreMap(widget.members);
    final unavailMap = _buildUnavailMap(widget.members);
    final tripLen = widget.group.tripLength ?? 1;
    final tol = widget.group.tripLengthTolerance ?? 0;
    final optimalRange = _findOptimalRange(
      scoreMap,
      tripLen,
      tol,
      widget.group.windowStart,
      widget.group.windowEnd,
    );

    // Local optimistic state for the show-unavail switch (fixes flicker)
    if (_localShowUnavail == null ||
        _lastSyncedUnavail != widget.showUnavail) {
      _localShowUnavail = widget.showUnavail;
      _lastSyncedUnavail = widget.showUnavail;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Trip info pill (if set)
        if (widget.group.tripLength != null ||
            widget.group.windowStart != null) ...[
          _TripInfoCard(group: widget.group),
          const SizedBox(height: 14),
        ],

        // Select-mode header (only when active)
        if (_selectMode) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.checklist_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${_selected.length} date${_selected.length == 1 ? '' : 's'} selected',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
              ),
              TextButton(
                onPressed: _exitSelectMode,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Cancel',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.6))),
              ),
            ]),
          ),
          const SizedBox(height: 10),
        ],

        // Select + Refresh buttons (only when NOT in select mode)
        if (!_selectMode) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  ref.invalidate(_groupMembersProvider(widget.group.memberIds));
                  ref.invalidate(groupOverridesProvider(widget.group.id));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Synced with personal calendars'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ));
                },
                icon: Icon(Icons.refresh_rounded,
                    color: cs.primary, size: 18),
                label: Text('Sync',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: _enterSelectMode,
                icon: Icon(Icons.checklist_rounded,
                    color: cs.primary, size: 18),
                label: Text('Select dates',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],

        // Calendar
        _SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: TableCalendar(
            firstDay: widget.group.windowStart ??
                DateTime.now().subtract(const Duration(days: 1)),
            lastDay: widget.group.windowEnd ??
                DateTime.now().add(const Duration(days: 365)),
            focusedDay: _clampFocused(_focusedDay),
            onDaySelected: (selected, focused) {
              setState(() => _focusedDay = focused);
              if (_selectMode) {
                final normed = _norm(selected);
                if (normed.isBefore(_today)) return;
                setState(() {
                  if (_selected.contains(normed)) {
                    _selected.remove(normed);
                  } else {
                    _selected.add(normed);
                  }
                });
              } else {
                _openDayDetail(selected);
              }
            },
            startingDayOfWeek: widget.startDay,
            selectedDayPredicate: (_) => false,
            onPageChanged: (f) => setState(() => _focusedDay = f),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, _) => _buildCell(
                  day, scoreMap, unavailMap, total, false, cs),
              todayBuilder: (ctx, day, _) => _buildCell(
                  day, scoreMap, unavailMap, total, true, cs),
              outsideBuilder: (ctx, day, _) => Center(
                  child: Text('${day.day}',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.2),
                          fontSize: 13))),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: cs.primary),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: cs.primary),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              weekendStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Apply button in select mode
        if (_selectMode) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected.isEmpty ? null : _applyBulkStatus,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                  _selected.isEmpty
                      ? 'Select dates to apply'
                      : 'Apply to ${_selected.length} date${_selected.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Show member votes — dropdown selector
        _SectionCard(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: InkWell(
            onTap: () async {
              final result = await showModalBottomSheet<Set<DateStatus>>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    _VoteFilterSheet(initial: _visibleVoteTypes),
              );
              if (result != null) {
                setState(() => _visibleVoteTypes = result);
              }
            },
            child: Row(children: [
              Icon(Icons.visibility_outlined,
                  size: 18, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Show member votes',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                          _visibleVoteTypes.isEmpty
                              ? 'No vote dots'
                              : _visibleVoteTypes
                                  .map((s) => s.label)
                                  .join(', '),
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: cs.onSurface
                                  .withValues(alpha: 0.72))),
                    ]),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: cs.onSurface.withValues(alpha: 0.45)),
            ]),
          ),
        ),

        // Show member legend if all-votes is on
        if (_showAllVotes && widget.members.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 6,
            children: widget.members.map((m) {
              final c = _colorFor(m.name);
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(m.name,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500)),
              ]);
            }).toList(),
          ),
        ],

        // Optimal date(s) below calendar
        if (optimalRange != null) ...[
          const SizedBox(height: 18),
          _SectionHeader(
              icon: Icons.star_outline_rounded,
              label: 'Optimal Date${optimalRange.length > 1 ? "s" : ""}',
              color: AppColors.accent),
          const SizedBox(height: 10),
          _OptimalRangeCard(
              range: optimalRange,
              scoreMap: scoreMap,
              total: total,
              tripLength: tripLen),
          const SizedBox(height: 10),
          _ConfirmationRow(
              group: widget.group,
              range: optimalRange,
              members: widget.members),
        ],
      ],
    );
  }

  // Calendar cell
  Widget _buildCell(
    DateTime day,
    Map<DateTime, double> scoreMap,
    Map<DateTime, int> unavailMap,
    int total,
    bool isToday,
    ColorScheme cs,
  ) {
    final normed = _norm(day);
    final now = _norm(DateTime.now());
    final isPast = normed.isBefore(now);
    final score = scoreMap[normed] ?? 0.0;
    final unavailCount = unavailMap[normed] ?? 0;
    // Color intensity: if minHeadcount is set, scale from 50% of min → 100% of min.
    // Below half of min = no green. Without min, scale from 0 → total members.
    final double availRatio;
    final minHc = widget.group.minHeadcount;
    if (minHc != null && minHc > 0) {
      final threshold = minHc / 2.0;
      final peak = minHc.toDouble();
      availRatio = ((score - threshold) / (peak - threshold)).clamp(0.0, 1.0);
    } else {
      availRatio = total > 0 ? (score / total).clamp(0.0, 1.0) : 0.0;
    }
    final hasAvail = availRatio > 0;
    // Always show unavailable indicators (toggle removed in v1.1.x).
    final hasUnavail = unavailCount > 0;

    Color? bgColor;
    if (hasAvail && !_showAllVotes) {
      bgColor = AppColors.available
          .withValues(alpha: 0.15 + availRatio * 0.85);
    }

    Color textColor;
    if (isPast) {
      textColor = cs.onSurface.withValues(alpha: 0.25);
    } else if (hasAvail && !_showAllVotes && availRatio >= 0.3) {
      textColor = Colors.white;
    } else if (isToday && !hasAvail) {
      textColor = cs.primary;
    } else {
      textColor = cs.onSurface;
    }

    // Build dot overlays for selected vote types.
    final voteDots = <Widget>[];
    if (_visibleVoteTypes.isNotEmpty && !isPast) {
      final votingMembers = widget.members.where((m) {
        for (final type in _visibleVoteTypes) {
          if (type == DateStatus.available &&
              m.available.contains(normed)) return true;
          if (type == DateStatus.likely && m.likely.contains(normed)) {
            return true;
          }
          if (type == DateStatus.maybe && m.maybe.contains(normed)) {
            return true;
          }
          if (type == DateStatus.unavailable &&
              m.unavailable.contains(normed)) return true;
        }
        return false;
      }).toList();

      for (var i = 0; i < votingMembers.length && i < 6; i++) {
        final m = votingMembers[i];
        final c = _colorFor(m.name);
        voteDots.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
        ));
      }
    }

    final isSelected = _selectMode && _selected.contains(normed);

    // Wrap in fixed-size SizedBox so all cells render at the same height
    // regardless of whether they have dots / selection rings / etc.
    return Center(
      child: SizedBox(
        width: 40, height: 40,
        child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isToday && bgColor == null
                ? Border.all(color: cs.primary, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text('${day.day}',
                style: TextStyle(
                    color: textColor,
                    fontWeight: hasAvail || isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                    fontSize: 13)),
          ),
        ),
        if (isSelected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary, width: 2.5),
              ),
            ),
          ),
        if (hasUnavail && !_showAllVotes)
          Positioned(
            right: 2, bottom: 2,
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: Color.lerp(
                  AppColors.danger.withValues(alpha: 0.4),
                  AppColors.danger,
                  (unavailCount / total).clamp(0.0, 1.0),
                ),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1),
              ),
            ),
          ),
        if (voteDots.isNotEmpty)
          Positioned(
            bottom: 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: voteDots),
          ),
      ],
        ),
      ),
    );
  }

  Map<DateTime, double> _buildScoreMap(List<MemberData> members) {
    final map = <DateTime, double>{};
    for (final m in members) {
      for (final d in {...m.available, ...m.likely, ...m.maybe}) {
        final normed = _norm(d);
        map[normed] = (map[normed] ?? 0) + m.scoreFor(normed);
      }
    }
    return map;
  }

  Map<DateTime, int> _buildUnavailMap(List<MemberData> members) {
    final map = <DateTime, int>{};
    for (final m in members) {
      for (final d in m.unavailable) {
        final normed = _norm(d);
        map[normed] = (map[normed] ?? 0) + 1;
      }
    }
    return map;
  }

  /// Finds the best consecutive range with highest AVERAGE score.
  /// Length ∈ [tripLength - tolerance, tripLength + tolerance] (≥1).
  /// Searches within [windowStart, windowEnd] if set, else next 365 days.
  List<DateTime>? _findOptimalRange(
    Map<DateTime, double> scoreMap,
    int tripLength,
    int tolerance,
    DateTime? windowStart,
    DateTime? windowEnd,
  ) {
    if (scoreMap.isEmpty || tripLength < 1) return null;
    final now = _norm(DateTime.now());
    final from = windowStart != null
        ? (windowStart.isAfter(now) ? _norm(windowStart) : now)
        : now;
    final to = windowEnd != null
        ? _norm(windowEnd)
        : now.add(const Duration(days: 365));

    final minLen = (tripLength - tolerance).clamp(1, 60);
    final maxLen = tripLength + tolerance;

    List<DateTime>? bestRange;
    double bestAvg = -1;
    int bestLenDiff = 999;

    for (var L = minLen; L <= maxLen; L++) {
      for (var start = from;
          !start.isAfter(to.subtract(Duration(days: L - 1)));
          start = start.add(const Duration(days: 1))) {
        double sum = 0;
        final range = <DateTime>[];
        for (var i = 0; i < L; i++) {
          final d = start.add(Duration(days: i));
          range.add(d);
          sum += scoreMap[d] ?? 0;
        }
        final avg = sum / L;
        final lenDiff = (L - tripLength).abs();
        // Prefer higher avg; on tie, prefer length closest to target
        if (avg > bestAvg + 0.001 ||
            (avg >= bestAvg - 0.001 && lenDiff < bestLenDiff)) {
          bestAvg = avg;
          bestLenDiff = lenDiff;
          bestRange = range;
        }
      }
    }
    return (bestAvg > 0) ? bestRange : null;
  }

  DateTime _clampFocused(DateTime d) {
    final ws = widget.group.windowStart;
    final we = widget.group.windowEnd;
    if (ws != null && d.isBefore(ws)) return ws;
    if (we != null && d.isAfter(we)) return we;
    return d;
  }

  Future<void> _openDayDetail(DateTime day) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailSheet(
        date: _norm(day),
        group: widget.group,
        members: widget.members,
      ),
    );
  }
}

// ─── Optimal date card ────────────────────────────────────────────────────────

class _OptimalRangeCard extends StatelessWidget {
  const _OptimalRangeCard({
    required this.range,
    required this.scoreMap,
    required this.total,
    required this.tripLength,
  });
  final List<DateTime> range;
  final Map<DateTime, double> scoreMap;
  final int total;
  final int tripLength;

  String _formatRange() {
    if (range.length == 1) return _formatFull(range.first);
    final first = range.first;
    final last = range.last;
    final sameMonth = first.month == last.month && first.year == last.year;
    if (sameMonth) {
      return '${_shortDay(first)} ${first.day} – ${_shortDay(last)} ${last.day} ${_shortMonth(first)}';
    }
    return '${_shortDay(first)} ${first.day} ${_shortMonth(first)} – ${_shortDay(last)} ${last.day} ${_shortMonth(last)}';
  }

  String _formatFull(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday'
    ];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  String _shortDay(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avgScore = range.isEmpty
        ? 0.0
        : range.map((d) => scoreMap[d] ?? 0).reduce((a, b) => a + b) /
            range.length;
    final ratio = total > 0 ? (avgScore / total).clamp(0.0, 1.0) : 0.0;
    final isPerfect = ratio >= 0.99;
    final barColor = isPerfect
        ? AppColors.available
        : const Color(0xFF5C6BC0);

    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${range.first.day}',
                    style: TextStyle(
                        color: barColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1)),
                Text(_shortMonth(range.first),
                    style: TextStyle(
                        color: barColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatRange(),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: cs.onSurface)),
                  if (tripLength > 1) ...[
                    const SizedBox(height: 2),
                    Text(formatTripLength(tripLength),
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor:
                              barColor.withValues(alpha: 0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                        isPerfect
                            ? 'Everyone'
                            : '${avgScore.toStringAsFixed(1)}/$total',
                        style: TextStyle(
                            fontSize: 12,
                            color: barColor,
                            fontWeight: FontWeight.w700)),
                  ]),
                ]),
          ),
        ]),
      ),
    );
  }

  String _shortMonth(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return m[d.month - 1];
  }
}

// ─── Trip info card (shows length + window when set) ─────────────────────────

class _TripInfoCard extends StatelessWidget {
  const _TripInfoCard({required this.group});
  final GroupModel group;

  String _formatDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLength = group.tripLength != null;
    final hasWindow = group.windowStart != null && group.windowEnd != null;

    return _SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.flag_outlined, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLength)
                  Text(formatTripLength(group.tripLength),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: cs.onSurface)),
                if (hasWindow)
                  Padding(
                    padding: EdgeInsets.only(top: hasLength ? 2 : 0),
                    child: Text(
                      '${_formatDate(group.windowStart!)} → ${_formatDate(group.windowEnd!)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
              ]),
        ),
      ]),
    );
  }
}

// ─── MEMBERS TAB ──────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.group, required this.members});
  final GroupModel group;
  final List<MemberData> members;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: group.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Invite code copied!'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _share(BuildContext context) async {
    final emoji = group.emoji ?? '👥';
    // App Store URL — replace with real link once published
    const appStoreUrl = 'https://apps.apple.com/app/group-planner';
    final text =
        'Join my group "${group.name}" $emoji on Group Point!\n\n'
        'Invite code: ${group.inviteCode}\n\n'
        'Download the app: $appStoreUrl';

    // Position origin for iPad popover anchor
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;

    try {
      await Share.share(
        text,
        subject: 'Join ${group.name} on Group Point',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Share failed: $e'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  void _copyLink(BuildContext context) {
    final emoji = group.emoji ?? '👥';
    const appStoreUrl = 'https://apps.apple.com/app/group-planner';
    final text =
        'Join my group "${group.name}" $emoji on Group Point!\n'
        'Invite code: ${group.inviteCode}\n'
        'Download: $appStoreUrl';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Invite message copied!'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _editMyName(
      BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final cs = Theme.of(context).colorScheme;

    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Your name in this group',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: cs.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Custom name',
            hintStyle:
                TextStyle(color: cs.onSurface.withValues(alpha: 0.35)),
            filled: true,
            fillColor: cs.onSurface.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Reset',
                  style: TextStyle(color: AppColors.danger))),
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child:
                  Text('Cancel', style: TextStyle(color: cs.primary))),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: cs.primary),
              child: const Text('Save')),
        ],
      ),
    );

    if (result == null) return;
    try {
      await ref
          .read(groupsNotifierProvider.notifier)
          .setMyNameInGroup(group.id, result.isEmpty ? null : result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Invite code (moved from Calendar tab)
        _SectionCard(
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.link, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite Code',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text(group.inviteCode,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                            color: cs.onSurface)),
                  ]),
            ),
            IconButton(
                onPressed: () => _copy(context),
                icon: Icon(Icons.copy_outlined, color: cs.primary),
                tooltip: 'Copy code'),
            IconButton(
                onPressed: () => _copyLink(context),
                icon: Icon(Icons.link, color: cs.primary),
                tooltip: 'Copy message'),
            IconButton(
                onPressed: () => _share(context),
                icon: Icon(Icons.ios_share, color: cs.primary),
                tooltip: 'Share'),
          ]),
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          icon: Icons.people_outline,
          label:
              '${group.memberIds.length} ${group.memberIds.length == 1 ? 'Member' : 'Members'}',
          color: AppColors.available,
        ),
        const SizedBox(height: 10),
        _SectionCard(
          child: Column(
            children: members.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final color = _colorFor(m.name);
              final isLast = i == members.length - 1;
              final isCreator = m.uid == group.createdBy;
              final isMe = m.uid == myUid;
              return Column(children: [
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailsBreakdownScreen(
                          group: group, members: [m]),
                    ),
                  ),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          m.name.isNotEmpty
                              ? m.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(m.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: cs.onSurface)),
                              ),
                              if (isCreator) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.14),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: const Text('Creator',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accent)),
                                ),
                              ],
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primary
                                        .withValues(alpha: 0.14),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text('You',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: cs.primary)),
                                ),
                                const Spacer(),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                      minWidth: 30, minHeight: 30),
                                  icon: Icon(Icons.edit_outlined,
                                      size: 16,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5)),
                                  onPressed: () => _editMyName(
                                      context, ref, m.name),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8, runSpacing: 4,
                              children: [
                                _CountChip(
                                    icon: Icons.check_circle_outline,
                                    color: AppColors.available,
                                    label: '${m.available.length}'),
                                _CountChip(
                                    icon: Icons.thumb_up_outlined,
                                    color: AppColors.likely,
                                    label: '${m.likely.length}'),
                                _CountChip(
                                    icon: Icons.help_outline,
                                    color: AppColors.maybe,
                                    label: '${m.maybe.length}'),
                                _CountChip(
                                    icon: Icons.cancel_outlined,
                                    color: AppColors.danger,
                                    label: '${m.unavailable.length}'),
                              ],
                            ),
                          ]),
                    ),
                    Icon(Icons.chevron_right,
                        color: cs.onSurface.withValues(alpha: 0.35), size: 20),
                  ]),
                ),
                ),
                if (!isLast)
                  Divider(
                      height: 1,
                      indent: 56,
                      color: cs.onSurface.withValues(alpha: 0.08)),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ─── ACTIVITY TAB ─────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.group, required this.members});
  final GroupModel group;
  final List<MemberData> members;

  String _nameFor(String uid) {
    final m = members.firstWhere(
      (m) => m.uid == uid,
      orElse: () => MemberData(
          uid: uid,
          name: 'Former member',
          available: {},
          likely: {},
          maybe: {},
          unavailable: {}),
    );
    return m.name;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final activityAsync = ref.watch(groupActivityProvider(group.id));

    return activityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history,
                      size: 44, color: cs.primary),
                ),
                const SizedBox(height: 20),
                Text('No activity yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                const SizedBox(height: 6),
                Text(
                    'Member actions will appear here.\nMark some dates to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        height: 1.5)),
              ]),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = entries[i];
            final name = _nameFor(e.uid);
            return _ActivityRow(entry: e, userName: name);
          },
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.userName});
  final ActivityEntry entry;
  final String userName;

  ({IconData icon, Color color, String verb}) _action() {
    switch (entry.action) {
      case 'created':
        return (
          icon: Icons.flag_outlined,
          color: AppColors.accent,
          verb: 'created the group'
        );
      case 'joined':
        return (
          icon: Icons.group_add_outlined,
          color: AppColors.available,
          verb: 'joined the group'
        );
      case 'left':
        return (
          icon: Icons.logout,
          color: AppColors.accent,
          verb: 'left the group'
        );
      case 'available':
        return (
          icon: Icons.check_circle_outline,
          color: AppColors.available,
          verb: 'is available'
        );
      case 'likely':
        return (
          icon: Icons.thumb_up_outlined,
          color: AppColors.likely,
          verb: 'is likely available'
        );
      case 'maybe':
        return (
          icon: Icons.help_outline,
          color: AppColors.maybe,
          verb: 'maybe available'
        );
      case 'unavailable':
        return (
          icon: Icons.cancel_outlined,
          color: AppColors.danger,
          verb: 'is unavailable'
        );
      case 'removed':
        return (
          icon: Icons.delete_outline,
          color: const Color(0xFF8A93A8),
          verb: 'removed availability'
        );
    }
    return (
      icon: Icons.circle_outlined,
      color: const Color(0xFF8A93A8),
      verb: entry.action
    );
  }

  String _formatDate(String? d) {
    if (d == null) return '';
    final dt = _parseDate(d);
    if (dt == null) return d;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return ' on ${m[dt.month - 1]} ${dt.day}';
  }

  String _relativeTime(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = _action();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: a.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(a.icon, color: a.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style:
                  TextStyle(fontSize: 14, color: cs.onSurface, height: 1.4),
              children: [
                TextSpan(
                    text: userName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' ${a.verb}'),
                TextSpan(
                    text: _formatDate(entry.date),
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_relativeTime(entry.timestamp),
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: 0.2)),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}


// ─── Day detail sheet ─────────────────────────────────────────────────────────

class _DayDetailSheet extends ConsumerWidget {
  const _DayDetailSheet({
    required this.date,
    required this.group,
    required this.members,
  });

  final DateTime date;
  final GroupModel group;
  final List<MemberData> members;

  String _formatDate(DateTime d) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    const days = [
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
      "Saturday", "Sunday"
    ];
    return "${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}";
  }

  ({IconData icon, Color color, String label}) _statusInfo(String key) {
    switch (key) {
      case "available":
        return (
          icon: Icons.check_circle_outline,
          color: AppColors.available,
          label: "Available"
        );
      case "likely":
        return (
          icon: Icons.thumb_up_outlined,
          color: AppColors.likely,
          label: "Likely"
        );
      case "maybe":
        return (
          icon: Icons.help_outline,
          color: AppColors.maybe,
          label: "Maybe"
        );
      case "unavailable":
        return (
          icon: Icons.cancel_outlined,
          color: AppColors.danger,
          label: "Unavailable"
        );
    }
    return (
      icon: Icons.remove_circle_outline,
      color: const Color(0xFF8A93A8),
      label: "Not marked"
    );
  }

  Future<void> _setOverride(BuildContext context, WidgetRef ref,
      MemberData me, String status) async {
    // ─── Personal-calendar conflict check ───────────────────────
    // If I'm trying to mark group Available/Likely/Maybe on a date my personal
    // calendar says I'm Unavailable, warn before proceeding.
    if (status == 'available' ||
        status == 'likely' ||
        status == 'maybe') {
      final personalData = ref.read(availabilityDataProvider).value;
      if (personalData != null) {
        final personalStatus = personalData.personalStatusOf(date);
        if (personalStatus == PersonalDateStatus.unavailable ||
            personalStatus == PersonalDateStatus.maybeUnavailable) {
          final confirmed = await _showPersonalConflictWarning(
              context, personalStatus, status);
          if (!confirmed) return;
        }
      }
    }

    final myGlobal = me.globalStatus[date];
    if (myGlobal != null && myGlobal != status && status != "none") {
      final confirmed = await _showWarning(context, myGlobal, status);
      if (!confirmed) return;
    }
    try {
      await ref
          .read(groupsNotifierProvider.notifier)
          .setMyOverrideInGroup(group.id, date, status);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Could not save: $e"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16)));
      }
    }
  }

  Future<bool> _showPersonalConflictWarning(BuildContext context,
      PersonalDateStatus personalStatus, String groupStatus) async {
    final cs = Theme.of(context).colorScheme;
    final personalLabel = personalStatus == PersonalDateStatus.unavailable
        ? 'Unavailable'
        : 'Maybe Unavailable';
    final groupLabel = _statusInfo(groupStatus).label;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Personal calendar conflict",
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: cs.onSurface)),
          ),
        ]),
        content: Text(
          "You marked this date as '$personalLabel' in your personal calendar. "
          "Setting it to '$groupLabel' here will only apply to this group — "
          "your personal calendar stays as is.",
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: cs.primary))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: cs.primary),
              child: const Text("Continue")),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _showWarning(
      BuildContext context, String global, String target) async {
    final cs = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text("Override profile setting?",
            style: TextStyle(
                fontWeight: FontWeight.w700, color: cs.onSurface)),
        content: Text(
            "Your profile shows you as ${_statusInfo(global).label} on this date. "
            "Setting it to ${_statusInfo(target).label} will apply only to this group.",
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: cs.primary))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: cs.primary),
              child: const Text("Override")),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _pickMyOverride(BuildContext context, WidgetRef ref,
      MemberData me) async {
    final cs = Theme.of(context).colorScheme;
    final myEffective = me.statusFor(date) ?? "none";

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cs.surface, borderRadius: BorderRadius.circular(20)),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text("Set my status for this group",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            ..._buildStatusOptions(context, myEffective),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );

    if (result != null && context.mounted) {
      await _setOverride(context, ref, me, result);
    }
  }

  List<Widget> _buildStatusOptions(BuildContext context, String current) {
    const statuses = ["available", "likely", "maybe", "unavailable"];
    return [
      ...statuses.map((s) => _optionTile(context, s, current == s)),
      _optionTile(context, "none", false, label: "Use profile setting"),
    ];
  }

  Widget _optionTile(BuildContext context, String status, bool isSelected,
      {String? label}) {
    final cs = Theme.of(context).colorScheme;
    final info = status == "none"
        ? (
            icon: Icons.refresh,
            color: cs.onSurface.withValues(alpha: 0.5),
            label: label ?? "Reset"
          )
        : _statusInfo(status);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: info.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(info.icon, color: info.color, size: 20),
      ),
      title: Text(info.label,
          style: TextStyle(
              fontWeight: FontWeight.w600, color: cs.onSurface)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: info.color, size: 22)
          : null,
      onTap: () => Navigator.pop(context, status),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final me = members.firstWhere(
      (m) => m.uid == myUid,
      orElse: () => MemberData(
          uid: myUid ?? "",
          name: "You",
          available: {},
          likely: {},
          maybe: {},
          unavailable: {}),
    );

    // Group members by effective status
    final byStatus = <String, List<MemberData>>{
      "available": [],
      "likely": [],
      "maybe": [],
      "unavailable": [],
      "none": [],
    };
    for (final m in members) {
      final s = m.statusFor(date) ?? "none";
      byStatus[s]!.add(m);
    }

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(_formatDate(date),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              children: [
                for (final status in [
                  "available",
                  "likely",
                  "maybe",
                  "unavailable",
                  "none"
                ])
                  if (byStatus[status]!.isNotEmpty)
                    _statusSection(
                        context, status, byStatus[status]!, date),
              ],
            ),
          ),
          // Override action for current user
          if (myUid != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pickMyOverride(context, ref, me),
                  icon: Icon(Icons.tune, color: cs.primary, size: 18),
                  label: Text("Set my status for this group",
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: cs.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _statusSection(BuildContext context, String status,
      List<MemberData> list, DateTime date) {
    final cs = Theme.of(context).colorScheme;
    final info = _statusInfo(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(children: [
              Icon(info.icon, size: 14, color: info.color),
              const SizedBox(width: 4),
              Text("${info.label} · ${list.length}",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: info.color)),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: list.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final isLast = i == list.length - 1;
                final isOverridden = m.overridden.contains(date);

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: info.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            m.name.isNotEmpty
                                ? m.name[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                                color: info.color,
                                fontWeight: FontWeight.w800,
                                fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(m.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface)),
                      ),
                      if (isOverridden)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text("Group-specific",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary)),
                        ),
                    ]),
                  ),
                  if (!isLast)
                    Divider(
                        height: 1,
                        indent: 52,
                        color: info.color.withValues(alpha: 0.1)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Confirmation row ────────────────────────────────────────────────────────

class _ConfirmationRow extends ConsumerStatefulWidget {
  const _ConfirmationRow({
    required this.group,
    required this.range,
    required this.members,
  });

  final GroupModel group;
  final List<DateTime> range;
  final List<MemberData> members;

  @override
  ConsumerState<_ConfirmationRow> createState() => _ConfirmationRowState();
}

class _ConfirmationRowState extends ConsumerState<_ConfirmationRow> {
  bool _saving = false;

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color _avatarColor(String key) {
    if (key.isEmpty) return AppColors.brandPrimary;
    return AppColors
        .avatarPalette[key.codeUnitAt(0) % AppColors.avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final firstDate = widget.range.first;
    final dateKey = _fmtDate(firstDate);
    final confirmedUids =
        widget.group.confirmations[dateKey] ?? const <String>[];
    final myConfirmed = myUid != null && confirmedUids.contains(myUid);
    final memberCount = widget.members.length;
    final confirmedCount = confirmedUids.length;
    final allConfirmed =
        memberCount > 0 && confirmedCount >= memberCount;

    // Once everyone confirmed, prompt current user to block in personal calendar.
    if (allConfirmed && myConfirmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybePromptPersonalBlock(dateKey, firstDate);
      });
    }

    final accent = allConfirmed
        ? AppColors.available
        : AppColors.brandPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allConfirmed
              ? AppColors.available.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              allConfirmed ? Icons.verified : Icons.how_to_vote_outlined,
              color: accent,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                allConfirmed
                    ? 'All members confirmed'
                    : 'Confirm this date',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface),
              ),
            ),
            Text(
              '$confirmedCount/$memberCount',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent),
            ),
          ]),
          const SizedBox(height: 8),
          if (confirmedUids.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: confirmedUids.map((uid) {
                final m = widget.members.firstWhere(
                  (m) => m.uid == uid,
                  orElse: () => MemberData(
                      uid: uid,
                      name: '?',
                      available: {},
                      likely: {},
                      maybe: {},
                      unavailable: {}),
                );
                final c = _avatarColor(m.name);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Text(m.name,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c)),
                  ]),
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _toggle,
              style: FilledButton.styleFrom(
                backgroundColor: myConfirmed
                    ? cs.onSurface.withValues(alpha: 0.06)
                    : accent,
                foregroundColor: myConfirmed
                    ? cs.onSurface.withValues(alpha: 0.7)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      myConfirmed ? 'Remove my confirmation' : 'Confirm',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          if (allConfirmed) ...[
            const SizedBox(height: 6),
            Text(
              'Heads up: dates can still be changed if plans shift.',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggle() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(groupsNotifierProvider.notifier)
          .toggleConfirmation(widget.group.id, widget.range.first);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not confirm: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _maybePromptPersonalBlock(
      String dateKey, DateTime firstDate) async {
    // Prompt only once per group×date using shared_preferences.
    final prefs = await SharedPreferences.getInstance();
    final key = 'gp_promoted_${widget.group.id}_$dateKey';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    if (!mounted) return;

    final cs = Theme.of(context).colorScheme;
    final isMulti = widget.range.length > 1;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.verified, color: AppColors.available, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Block in personal calendar?',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: cs.onSurface)),
          ),
        ]),
        content: Text(
          isMulti
              ? "Everyone confirmed ${widget.range.length} dates for this trip. "
                  "Mark them as Unavailable in your personal calendar so other groups know you're busy?"
              : "Everyone confirmed this date. Mark it as Unavailable in your personal calendar so other groups know you're busy?",
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Not now",
                  style: TextStyle(color: cs.primary))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.available),
              child: const Text('Block in personal',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (result == true && mounted) {
      final notifier = ref.read(availabilityNotifierProvider.notifier);
      try {
        for (final d in widget.range) {
          await notifier.setPersonalStatus(d, PersonalDateStatus.unavailable);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Blocked ${widget.range.length} date${widget.range.length == 1 ? '' : 's'} in your personal calendar'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not block: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        }
      }
    }
  }
}

// ─── Vote filter sheet ───────────────────────────────────────────────────────

class _VoteFilterSheet extends StatefulWidget {
  const _VoteFilterSheet({required this.initial});
  final Set<DateStatus> initial;

  @override
  State<_VoteFilterSheet> createState() => _VoteFilterSheetState();
}

class _VoteFilterSheetState extends State<_VoteFilterSheet> {
  late Set<DateStatus> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initial);
  }

  Color _colorFor(DateStatus s) => switch (s) {
        DateStatus.available => AppColors.available,
        DateStatus.likely => AppColors.likely,
        DateStatus.maybe => AppColors.maybe,
        DateStatus.unavailable => AppColors.danger,
        DateStatus.none => Colors.transparent,
      };

  IconData _iconFor(DateStatus s) => switch (s) {
        DateStatus.available => Icons.check_circle_outline,
        DateStatus.likely => Icons.thumb_up_outlined,
        DateStatus.maybe => Icons.help_outline,
        DateStatus.unavailable => Icons.cancel_outlined,
        DateStatus.none => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.surface, borderRadius: BorderRadius.circular(20)),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Text('Show member votes',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('Choose which statuses appear as dots on the calendar',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55))),
          const SizedBox(height: 8),
          ...DateStatus.values.where((s) => s != DateStatus.none).map((s) {
            final c = _colorFor(s);
            final isSelected = _selected.contains(s);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(s);
                  } else {
                    _selected.remove(s);
                  }
                });
              },
              activeColor: c,
              controlAffinity: ListTileControlAffinity.trailing,
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(s), color: c, size: 18),
              ),
              title: Text(s.label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
            );
          }),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, <DateStatus>{}),
                  child: Text('Hide all',
                      style: TextStyle(color: cs.primary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
