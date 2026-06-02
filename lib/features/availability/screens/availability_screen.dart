import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/availability_provider.dart';
import '../../../core/theme_provider.dart';
import '../../../core/design_tokens.dart';

// ─── Status colors ────────────────────────────────────────────────────────────

Color statusColor(DateStatus s) => switch (s) {
      DateStatus.available => AppColors.available,
      DateStatus.likely => AppColors.likely,
      DateStatus.maybe => AppColors.maybe,
      DateStatus.unavailable => AppColors.danger,
      DateStatus.none => Colors.transparent,
    };

IconData statusIcon(DateStatus s) => switch (s) {
      DateStatus.available => Icons.check_circle_outline,
      DateStatus.likely => Icons.thumb_up_outlined,
      DateStatus.maybe => Icons.help_outline,
      DateStatus.unavailable => Icons.cancel_outlined,
      DateStatus.none => Icons.circle_outlined,
    };

// ─── Main screen ─────────────────────────────────────────────────────────────

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  DateTime _focusedDay = DateTime.now();
  bool _selectMode = false;
  bool _detailsExpanded = false;
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

  Future<void> _onDayTapped(DateTime day, AvailabilityData data) async {
    if (day.isBefore(_today)) return;
    final normed = _norm(day);

    // In select mode, toggle the date in/out of the selection
    if (_selectMode) {
      setState(() {
        if (_selected.contains(normed)) {
          _selected.remove(normed);
        } else {
          _selected.add(normed);
        }
      });
      return;
    }

    // Normal mode: show status picker
    final current = data.statusOf(normed);
    final result = await showModalBottomSheet<DateStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusPickerSheet(day: normed, current: current),
    );

    if (result != null && mounted) {
      try {
        await ref
            .read(availabilityNotifierProvider.notifier)
            .setDateStatus(normed, result);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not update: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        }
      }
    }
  }

  Future<void> _applyBulkStatus() async {
    if (_selected.isEmpty) return;
    final result = await showModalBottomSheet<DateStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkStatusPickerSheet(count: _selected.length),
    );
    if (result == null || !mounted) return;

    final notifier = ref.read(availabilityNotifierProvider.notifier);
    try {
      for (final d in _selected) {
        await notifier.setDateStatus(d, result);
      }
      if (mounted) _exitSelectMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not update: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(availabilityDataProvider);
    final startDay = ref.watch(startingDayOfWeekProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode
            ? '${_selected.length} selected'
            : 'My Availability'),
        centerTitle: false,
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close), onPressed: _exitSelectMode)
            : null,
        actions: [
          if (!_selectMode)
            TextButton.icon(
              onPressed: _enterSelectMode,
              icon: Icon(Icons.checklist_rounded, color: cs.primary, size: 20),
              label: Text('Select',
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      bottomNavigationBar: _selectMode
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                      top: BorderSide(
                          color: cs.onSurface.withValues(alpha: 0.08))),
                ),
                child: SizedBox(
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
              ),
            )
          : null,
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          return ListView(
            children: [
              // ── Calendar ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TableCalendar(
                  firstDay:
                      DateTime.now().subtract(const Duration(days: 1)),
                  lastDay:
                      DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  startingDayOfWeek: startDay,
                  selectedDayPredicate: (_) => false,
                  onDaySelected: (selected, focused) {
                    setState(() => _focusedDay = focused);
                    _onDayTapped(selected, data);
                  },
                  onPageChanged: (f) =>
                      setState(() => _focusedDay = f),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (ctx, day, _) =>
                        _dayCell(day, data, cs),
                    todayBuilder: (ctx, day, _) =>
                        _dayCell(day, data, cs, isToday: true),
                    outsideBuilder: (ctx, day, _) => Center(
                      child: Text('${day.day}',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.2),
                              fontSize: 14)),
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    leftChevronIcon:
                        Icon(Icons.chevron_left, color: cs.primary),
                    rightChevronIcon:
                        Icon(Icons.chevron_right, color: cs.primary),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    weekendStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              // ── Legend ──────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: DateStatus.values
                      .where((s) => s != DateStatus.none)
                      .map((s) => _LegendDot(
                          color: statusColor(s), label: s.label))
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),

              // ── Details dropdown ─────────────────────────────────
              _buildDetailsHeader(data, cs),
              if (_detailsExpanded) ...[
                const SizedBox(height: 10),
                _buildGroupedList(data, cs),
              ],

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _dayCell(DateTime day, AvailabilityData data, ColorScheme cs,
      {bool isToday = false}) {
    final normed = _norm(day);
    final isPast = normed.isBefore(_today);
    final status = data.statusOf(normed);
    final hasStatus = status != DateStatus.none;
    final color = statusColor(status);

    Color textColor;
    if (isPast) {
      textColor = cs.onSurface.withValues(alpha: 0.22);
    } else if (hasStatus) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = cs.primary;
    } else {
      textColor = cs.onSurface;
    }

    final isSelected = _selectMode && _selected.contains(normed);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: hasStatus
                ? BoxDecoration(color: color, shape: BoxShape.circle)
                : isToday
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: cs.primary, width: 1.5),
                      )
                    : null,
            child: Center(
              child: Text('${day.day}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: hasStatus || isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                    fontSize: 14,
                  )),
            ),
          ),
          if (isSelected)
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary, width: 2.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsHeader(AvailabilityData data, ColorScheme cs) {
    final count = data.available.length +
        data.likely.length +
        data.maybe.length +
        data.unavailable.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(Icons.list_alt_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text('Details',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: 0.2)),
            const SizedBox(width: 6),
            if (count > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.6))),
              ),
            const Spacer(),
            Icon(
              _detailsExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: cs.onSurface.withValues(alpha: 0.4),
              size: 20,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildGroupedList(AvailabilityData data, ColorScheme cs) {
    // Collect all marked dates
    final all = <DateTime, DateStatus>{};
    for (final d in data.available) all[d] = DateStatus.available;
    for (final d in data.likely) all[d] = DateStatus.likely;
    for (final d in data.maybe) all[d] = DateStatus.maybe;
    for (final d in data.unavailable) all[d] = DateStatus.unavailable;

    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(Icons.touch_app_outlined,
                color: cs.onSurface.withValues(alpha: 0.3), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap any date to set your availability.',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                    height: 1.4),
              ),
            ),
          ]),
        ),
      );
    }

    final sorted = all.keys.toList()..sort();
    final groups = _buildGroups(sorted, all);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: groups.asMap().entries.map((entry) {
            final i = entry.key;
            final group = entry.value;
            final isLast = i == groups.length - 1;
            final color = statusColor(group.status);

            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon(group.status),
                        color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatGroupRange(group),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(group.status.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                  TextButton(
                    onPressed: () =>
                        _openCalendarEditor(context, group, data),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Edit',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 74,
                    color: cs.onSurface.withValues(alpha: 0.08)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ── Booking.com-style calendar editor ─────────────────────────────────────

  Future<void> _openCalendarEditor(
      BuildContext context, _DateGroup group, AvailabilityData data) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalendarEditorSheet(
        initialDates: group.dates.toSet(),
        initialStatus: group.status,
        allData: data,
        onApply: (selectedDates, status) async {
          final notifier =
              ref.read(availabilityNotifierProvider.notifier);
          // Remove old dates that were deselected
          for (final d in group.dates) {
            if (!selectedDates.contains(d)) {
              await notifier.setDateStatus(d, DateStatus.none);
            }
          }
          // Set all selected dates to chosen status
          for (final d in selectedDates) {
            await notifier.setDateStatus(d, status);
          }
        },
      ),
    );
  }

  // ── Grouping helpers ───────────────────────────────────────────────────────

  List<_DateGroup> _buildGroups(
      List<DateTime> sorted, Map<DateTime, DateStatus> statusMap) {
    final groups = <_DateGroup>[];
    if (sorted.isEmpty) return groups;

    var runDates = [sorted.first];
    var runStatus = statusMap[sorted.first]!;

    for (var i = 1; i < sorted.length; i++) {
      final d = sorted[i];
      final prev = sorted[i - 1];
      final s = statusMap[d]!;
      if (d.difference(prev).inDays == 1 && s == runStatus) {
        runDates.add(d);
      } else {
        groups.add(_DateGroup(dates: runDates, status: runStatus));
        runDates = [d];
        runStatus = s;
      }
    }
    groups.add(_DateGroup(dates: runDates, status: runStatus));
    return groups;
  }

  String _formatGroupRange(_DateGroup group) {
    if (group.dates.length == 1) return _formatFull(group.dates.first);
    final first = group.dates.first;
    final last = group.dates.last;
    final sameMonth =
        first.month == last.month && first.year == last.year;
    if (sameMonth) {
      return '${_shortDay(first)} ${first.day} – ${_shortDay(last)} ${last.day} ${_shortMonth(first)}';
    }
    return '${_shortDay(first)} ${first.day} ${_shortMonth(first)} – ${_shortDay(last)} ${last.day} ${_shortMonth(last)}';
  }

  String _shortDay(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  String _shortMonth(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return m[d.month - 1];
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
}

// ─── Status picker sheet (tap on calendar day) ───────────────────────────────

class _StatusPickerSheet extends StatelessWidget {
  const _StatusPickerSheet({required this.day, required this.current});
  final DateTime day;
  final DateStatus current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 14),
          Text(_formatDate(day),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('How available are you?',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          ...DateStatus.values
              .where((s) => s != DateStatus.none)
              .map((s) => _StatusOption(
                    status: s,
                    isSelected: current == s,
                    onTap: () => Navigator.pop(context, s),
                  )),
          if (current != DateStatus.none)
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:
                      cs.onSurface.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    size: 20),
              ),
              title: Text('Remove',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.6))),
              onTap: () => Navigator.pop(context, DateStatus.none),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) {
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
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });
  final DateStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(statusIcon(status), color: color, size: 20),
      ),
      title: Text(status.label,
          style: TextStyle(
              fontWeight: FontWeight.w600, color: cs.onSurface)),
      subtitle: Text(_subtitle(status),
          style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.45))),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: color, size: 22)
          : null,
      onTap: onTap,
    );
  }

  String _subtitle(DateStatus s) => switch (s) {
        DateStatus.available => 'Yes, I can make it',
        DateStatus.likely => 'Probably yes, leaning towards yes',
        DateStatus.maybe => 'Not sure yet, waiting to confirm',
        DateStatus.unavailable => "No, I can't make it",
        DateStatus.none => '',
      };
}

// ─── Booking.com-style calendar editor ───────────────────────────────────────

class _CalendarEditorSheet extends ConsumerStatefulWidget {
  const _CalendarEditorSheet({
    required this.initialDates,
    required this.initialStatus,
    required this.allData,
    required this.onApply,
  });

  final Set<DateTime> initialDates;
  final DateStatus initialStatus;
  final AvailabilityData allData;
  final Future<void> Function(Set<DateTime> dates, DateStatus status) onApply;

  @override
  ConsumerState<_CalendarEditorSheet> createState() =>
      _CalendarEditorSheetState();
}

class _CalendarEditorSheetState
    extends ConsumerState<_CalendarEditorSheet> {
  late Set<DateTime> _selected;
  late DateStatus _status;
  DateTime _focusedDay = DateTime.now();
  bool _saving = false;

  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime get _today => _norm(DateTime.now());

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialDates);
    _status = widget.initialStatus;
    if (_selected.isNotEmpty) {
      _focusedDay = _selected.first;
    }
  }

  void _toggleDay(DateTime day) {
    final normed = _norm(day);
    if (normed.isBefore(_today)) return;
    setState(() {
      if (_selected.contains(normed)) {
        _selected.remove(normed);
      } else {
        _selected.add(normed);
      }
    });
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      await widget.onApply(_selected, _status);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final startDay = ref.watch(startingDayOfWeekProvider);
    final selColor = statusColor(_status);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                child: Text('Edit Dates',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ),
              Text('${_selected.length} selected',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500)),
            ]),
          ),

          const SizedBox(height: 12),

          // Status chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: DateStatus.values
                  .where((s) => s != DateStatus.none)
                  .map((s) {
                final isSelected = _status == s;
                final c = statusColor(s);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? c
                            : c.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon(s),
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : c),
                          const SizedBox(width: 5),
                          Text(s.label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : c)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Calendar
          Expanded(
            child: TableCalendar(
              firstDay:
                  DateTime.now().subtract(const Duration(days: 1)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              startingDayOfWeek: startDay,
              selectedDayPredicate: (_) => false,
              onDaySelected: (selected, focused) {
                setState(() => _focusedDay = focused);
                _toggleDay(selected);
              },
              onPageChanged: (f) =>
                  setState(() => _focusedDay = f),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (ctx, day, _) =>
                    _editorCell(day, selColor, cs),
                todayBuilder: (ctx, day, _) =>
                    _editorCell(day, selColor, cs, isToday: true),
                outsideBuilder: (ctx, day, _) => Center(
                  child: Text('${day.day}',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.2),
                          fontSize: 14)),
                ),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                weekendStyle: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    (_saving || _selected.isEmpty) ? null : _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: selColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _selected.isEmpty
                            ? 'No dates selected'
                            : 'Apply to ${_selected.length} date${_selected.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _editorCell(DateTime day, Color selColor, ColorScheme cs,
      {bool isToday = false}) {
    final normed = _norm(day);
    final isPast = normed.isBefore(_today);
    final isSelected = _selected.contains(normed);

    // Other existing statuses (not in current selection)
    final existingStatus = widget.allData.statusOf(normed);
    final hasOther = existingStatus != DateStatus.none &&
        !widget.initialDates.contains(normed);

    Color? bg;
    Color textColor = isPast
        ? cs.onSurface.withValues(alpha: 0.22)
        : cs.onSurface;
    BoxBorder? border;

    if (isSelected) {
      bg = selColor;
      textColor = Colors.white;
    } else if (hasOther) {
      bg = statusColor(existingStatus).withValues(alpha: 0.35);
      textColor = cs.onSurface;
    } else if (isToday) {
      border = Border.all(color: cs.primary, width: 1.5);
      textColor = cs.primary;
    }

    return Center(
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Center(
          child: Text('${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight:
                    isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                fontSize: 14,
              )),
        ),
      ),
    );
  }
}

// ─── Legend dot ───────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 9, height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
              fontWeight: FontWeight.w500)),
    ]);
  }
}

// ─── Date group model ─────────────────────────────────────────────────────────

class _DateGroup {
  final List<DateTime> dates;
  final DateStatus status;
  const _DateGroup({required this.dates, required this.status});
}

// ─── Bulk status picker (for multi-select) ────────────────────────────────────

class _BulkStatusPickerSheet extends StatelessWidget {
  const _BulkStatusPickerSheet({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 14),
          Text('Apply to $count date${count == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('Choose a status for all selected dates',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          ...DateStatus.values
              .where((s) => s != DateStatus.none)
              .map((s) => _StatusOption(
                    status: s,
                    isSelected: false,
                    onTap: () => Navigator.pop(context, s),
                  )),
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline,
                  color: cs.onSurface.withValues(alpha: 0.5), size: 20),
            ),
            title: Text('Remove all',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.6))),
            onTap: () => Navigator.pop(context, DateStatus.none),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
