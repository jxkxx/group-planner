import 'package:flutter/material.dart';
import '../models/group_model.dart';

/// Shared widget for setting trip length (+ tolerance) and time window.
class TripSettings extends StatefulWidget {
  const TripSettings({
    super.key,
    this.initialTripLength,
    this.initialTripLengthTolerance,
    this.initialWindowStart,
    this.initialWindowEnd,
    required this.onChanged,
    this.initialMinHeadcount,
  });

  final int? initialTripLength;
  final int? initialTripLengthTolerance;
  final int? initialMinHeadcount;
  final DateTime? initialWindowStart;
  final DateTime? initialWindowEnd;
  final void Function(int? tripLength, int? tolerance, DateTime? start,
      DateTime? end, int? minHeadcount) onChanged;

  @override
  State<TripSettings> createState() => _TripSettingsState();
}

class _TripSettingsState extends State<TripSettings> {
  late bool _lengthEnabled;
  late bool _windowEnabled;
  late int _length;
  late int _tolerance;
  late bool _headcountEnabled;
  late int _minHeadcount;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _lengthEnabled = widget.initialTripLength != null;
    _length = widget.initialTripLength ?? 2;
    _tolerance = widget.initialTripLengthTolerance ?? 0;
    _headcountEnabled = widget.initialMinHeadcount != null;
    _minHeadcount = widget.initialMinHeadcount ?? 2;
    _windowEnabled = widget.initialWindowStart != null;
    _start = widget.initialWindowStart;
    _end = widget.initialWindowEnd;
  }

  void _emit() {
    widget.onChanged(
      _lengthEnabled ? _length : null,
      _lengthEnabled ? _tolerance : null,
      _windowEnabled ? _start : null,
      _windowEnabled ? _end : null,
      _headcountEnabled ? _minHeadcount : null,
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
      initialDateRange: (_start != null && _end != null)
          ? DateTimeRange(start: _start!, end: _end!)
          : DateTimeRange(
              start: today,
              end: today.add(const Duration(days: 7))),
    );
    if (result != null) {
      setState(() {
        _start = result.start;
        _end = result.end;
      });
      _emit();
    }
  }

  Future<void> _pickMonths() async {
    final result = await showModalBottomSheet<({DateTime start, DateTime end})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MonthPickerSheet(initialStart: _start, initialEnd: _end),
    );
    if (result != null) {
      setState(() {
        _start = result.start;
        _end = result.end;
      });
      _emit();
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _lengthSubtitle() {
    if (!_lengthEnabled) return 'Members can mark any single day';
    if (_tolerance == 0) return formatTripLength(_length);
    final low = (_length - _tolerance).clamp(1, 30);
    final high = _length + _tolerance;
    return 'Around ${formatTripLength(_length)}  ·  $low–$high days';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Trip length ─────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              title: Text('Set trip length',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              subtitle: Text(_lengthSubtitle(),
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55))),
              value: _lengthEnabled,
              activeThumbColor: cs.primary,
              onChanged: (v) {
                setState(() => _lengthEnabled = v);
                _emit();
              },
            ),
            if (_lengthEnabled) ...[
              Divider(
                  height: 1,
                  indent: 16, endIndent: 16,
                  color: cs.onSurface.withValues(alpha: 0.06)),
              // Length stepper
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  Text('Length',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface)),
                  const Spacer(),
                  _CircleBtn(
                    icon: Icons.remove,
                    onTap: _length > 1
                        ? () {
                            setState(() => _length--);
                            _emit();
                          }
                        : null,
                  ),
                  Container(
                    width: 56,
                    alignment: Alignment.center,
                    child: Text('$_length',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface)),
                  ),
                  _CircleBtn(
                    icon: Icons.add,
                    onTap: _length < 30
                        ? () {
                            setState(() => _length++);
                            _emit();
                          }
                        : null,
                  ),
                ]),
              ),
              Divider(
                  height: 1,
                  indent: 16, endIndent: 16,
                  color: cs.onSurface.withValues(alpha: 0.06)),
              // Tolerance stepper
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tolerance ± days',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface)),
                        Text('Allow shorter or longer trips',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                      ]),
                  const Spacer(),
                  _CircleBtn(
                    icon: Icons.remove,
                    onTap: _tolerance > 0
                        ? () {
                            setState(() => _tolerance--);
                            _emit();
                          }
                        : null,
                  ),
                  Container(
                    width: 56,
                    alignment: Alignment.center,
                    child: Text('±$_tolerance',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _tolerance == 0
                                ? cs.onSurface.withValues(alpha: 0.4)
                                : cs.onSurface)),
                  ),
                  _CircleBtn(
                    icon: Icons.add,
                    onTap: _tolerance < 7
                        ? () {
                            setState(() => _tolerance++);
                            _emit();
                          }
                        : null,
                  ),
                ]),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 12),

        // ── Time window ─────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              title: Text('Set time range',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              subtitle: Text(
                  _windowEnabled && _start != null && _end != null
                      ? '${_formatDate(_start!)}  →  ${_formatDate(_end!)}'
                      : 'Members can pick any future date',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55))),
              value: _windowEnabled,
              activeThumbColor: cs.primary,
              onChanged: (v) {
                setState(() => _windowEnabled = v);
                if (v && (_start == null || _end == null)) {
                  _pickRange();
                } else {
                  _emit();
                }
              },
            ),
            if (_windowEnabled) ...[
              Divider(
                  height: 1,
                  indent: 16, endIndent: 16,
                  color: cs.onSurface.withValues(alpha: 0.06)),
              ListTile(
                onTap: _pickRange,
                leading: Icon(Icons.date_range, color: cs.primary, size: 22),
                title: Text('Custom date range',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                subtitle: _start != null && _end != null
                    ? Text(
                        '${_formatDate(_start!)} → ${_formatDate(_end!)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5)))
                    : null,
                trailing: Icon(Icons.chevron_right,
                    color: cs.onSurface.withValues(alpha: 0.35)),
              ),
              Divider(
                  height: 1,
                  indent: 16, endIndent: 16,
                  color: cs.onSurface.withValues(alpha: 0.06)),
              ListTile(
                onTap: _pickMonths,
                leading:
                    Icon(Icons.calendar_view_month, color: cs.primary, size: 22),
                title: Text('Whole month(s)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                trailing: Icon(Icons.chevron_right,
                    color: cs.onSurface.withValues(alpha: 0.35)),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 12),

        // ── Minimum headcount ───────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              title: Text('Required headcount',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              subtitle: Text(
                  _headcountEnabled
                      ? 'Trip needs at least $_minHeadcount people available'
                      : 'Trip can happen with any number of people',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55))),
              value: _headcountEnabled,
              activeThumbColor: cs.primary,
              onChanged: (v) {
                setState(() => _headcountEnabled = v);
                _emit();
              },
            ),
            if (_headcountEnabled) ...[
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.onSurface.withValues(alpha: 0.06)),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Minimum',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface)),
                          Text(
                              'Fewest people needed for the trip to happen',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.5))),
                        ]),
                  ),
                  const SizedBox(width: 6),
                  _CircleBtn(
                    icon: Icons.remove,
                    onTap: _minHeadcount > 1
                        ? () {
                            setState(() => _minHeadcount--);
                            _emit();
                          }
                        : null,
                  ),
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Text('$_minHeadcount',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface)),
                  ),
                  _CircleBtn(
                    icon: Icons.add,
                    onTap: _minHeadcount < 100
                        ? () {
                            setState(() => _minHeadcount++);
                            _emit();
                          }
                        : null,
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: enabled
                ? cs.primary.withValues(alpha: 0.12)
                : cs.onSurface.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size: 18,
              color: enabled
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}

// ─── Month picker sheet ───────────────────────────────────────────────────────

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({this.initialStart, this.initialEnd});
  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;
  final Set<int> _selectedMonths = {}; // (year * 12 + month) keys

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  int _key(int y, int m) => y * 12 + m;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;

    if (widget.initialStart != null && widget.initialEnd != null) {
      // Pre-fill with the month range if it falls neatly on months
      final s = widget.initialStart!;
      final e = widget.initialEnd!;
      var cur = DateTime(s.year, s.month, 1);
      final end = DateTime(e.year, e.month, 1);
      while (!cur.isAfter(end)) {
        _selectedMonths.add(_key(cur.year, cur.month));
        cur = DateTime(cur.year, cur.month + 1, 1);
      }
      _year = s.year;
    }
  }

  void _toggle(int month) {
    final k = _key(_year, month);
    setState(() {
      if (_selectedMonths.contains(k)) {
        _selectedMonths.remove(k);
      } else {
        _selectedMonths.add(k);
      }
    });
  }

  void _apply() {
    if (_selectedMonths.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final keys = _selectedMonths.toList()..sort();
    final firstKey = keys.first;
    final lastKey = keys.last;
    final startYear = firstKey ~/ 12;
    final startMonth = firstKey % 12;
    final endYear = lastKey ~/ 12;
    final endMonth = lastKey % 12;
    final start = DateTime(startYear, startMonth, 1);
    final end = DateTime(endYear, endMonth + 1, 0); // last day of end month
    Navigator.pop(context, (start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currentYearMonth = now.year * 12 + now.month;

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
          // Year selector
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _year > now.year
                  ? () => setState(() => _year--)
                  : null,
              color: cs.primary,
            ),
            Text('$_year',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _year < now.year + 3
                  ? () => setState(() => _year++)
                  : null,
              color: cs.primary,
            ),
          ]),
          const SizedBox(height: 12),
          // Months grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: List.generate(12, (i) {
                final month = i + 1;
                final k = _key(_year, month);
                final isSelected = _selectedMonths.contains(k);
                final isPast = _year * 12 + month < currentYearMonth;

                return GestureDetector(
                  onTap: isPast ? null : () => _toggle(month),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary
                          : (isPast
                              ? cs.onSurface.withValues(alpha: 0.03)
                              : cs.onSurface.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(_monthLabels[i],
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isPast
                                ? cs.onSurface.withValues(alpha: 0.25)
                                : (isSelected
                                    ? Colors.white
                                    : cs.onSurface))),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedMonths.isEmpty ? null : _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                    _selectedMonths.isEmpty
                        ? 'Select at least one month'
                        : 'Apply (${_selectedMonths.length} ${_selectedMonths.length == 1 ? "month" : "months"})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}
