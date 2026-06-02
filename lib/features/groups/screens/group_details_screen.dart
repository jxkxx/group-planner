import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import 'group_detail_screen.dart' show MemberData;
import '../../../core/design_tokens.dart';

class GroupDetailsBreakdownScreen extends ConsumerWidget {
  const GroupDetailsBreakdownScreen({
    super.key,
    required this.group,
    required this.members,
  });

  final GroupModel group;
  final List<MemberData> members;

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF5C6BC0), AppColors.available, AppColors.danger,
      AppColors.accent, AppColors.info, AppColors.purple,
      AppColors.likely, AppColors.maybe, Color(0xFF7E57C2),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Details'), centerTitle: false),
      body: members.isEmpty
          ? Center(
              child: Text('No members yet.',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5))),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final m = members[i];
                return _MemberCard(
                    member: m,
                    color: _avatarColor(m.name),
                    isCreator: m.uid == group.createdBy);
              },
            ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.color,
    required this.isCreator,
  });

  final MemberData member;
  final Color color;
  final bool isCreator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  member.name.isNotEmpty
                      ? member.name[0].toUpperCase()
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
              child: Row(children: [
                Flexible(
                  child: Text(member.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: cs.onSurface)),
                ),
                if (isCreator) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Creator',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent)),
                  ),
                ],
              ]),
            ),
          ]),
        ),

        Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),

        if (_isEmpty(member))
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No dates marked yet.',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontSize: 13)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(children: [
              _StatusSection(
                label: 'Available',
                color: AppColors.available,
                icon: Icons.check_circle_outline,
                dates: member.available,
              ),
              _StatusSection(
                label: 'Likely',
                color: AppColors.likely,
                icon: Icons.thumb_up_outlined,
                dates: member.likely,
              ),
              _StatusSection(
                label: 'Maybe',
                color: AppColors.maybe,
                icon: Icons.help_outline,
                dates: member.maybe,
              ),
              _StatusSection(
                label: 'Unavailable',
                color: AppColors.danger,
                icon: Icons.cancel_outlined,
                dates: member.unavailable,
              ),
            ]),
          ),
      ]),
    );
  }

  bool _isEmpty(MemberData m) =>
      m.available.isEmpty &&
      m.likely.isEmpty &&
      m.maybe.isEmpty &&
      m.unavailable.isEmpty;
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.label,
    required this.color,
    required this.icon,
    required this.dates,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Set<DateTime> dates;

  String _short(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) return const SizedBox.shrink();
    final sorted = dates.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text('$label · ${dates.length}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: sorted.map((d) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_short(d),
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
