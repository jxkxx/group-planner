import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/screens/group_detail_screen.dart';
import '../services/account_deletion.dart';
import '../../onboarding/onboarding_provider.dart';
import '../../onboarding/onboarding_screen.dart';
import 'legal_screen.dart';
import '../../../core/design_tokens.dart';

final _profileProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value({});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data() ?? {});
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _editing = false;
  bool _editingNickname = false;
  bool _saving = false;
  bool _savingNickname = false;

  // Options expansion state
  bool _appearanceExpanded = false;
  bool _datesExpanded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
            {'displayName': name},
            SetOptions(merge: true),
          );
      await FirebaseAuth.instance.currentUser!.updateDisplayName(name);
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNickname() async {
    final nick = _nicknameController.text.trim();
    setState(() => _savingNickname = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'nickname': nick.isEmpty ? FieldValue.delete() : nick},
        SetOptions(merge: true),
      );
      if (mounted) setState(() => _editingNickname = false);
    } finally {
      if (mounted) setState(() => _savingNickname = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed == true) await FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteAccount() async {
    final cs = Theme.of(context).colorScheme;

    // First confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete account?',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: cs.onSurface)),
        content: Text(
          'This permanently deletes your account, profile, and all your '
          'availability data. Groups you created will be transferred to '
          'another member, or deleted if you\'re the only one. This cannot '
          'be undone.',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: cs.primary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await deleteAccountAndData();

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    switch (result) {
      case DeletionSuccess():
        // Auth state listener in main.dart will redirect to sign-in
        break;
      case DeletionNeedsReauth():
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: cs.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('Please sign in again',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: cs.onSurface)),
            content: Text(
              'For security, account deletion requires a recent sign-in. '
              'Please sign out, sign back in, then try deleting your '
              'account again.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK', style: TextStyle(color: cs.primary))),
            ],
          ),
        );
      case DeletionError(:final message):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        }
    }
  }

  void _showStartDayPicker(BuildContext context, int currentIndex) {
    final cs = Theme.of(context).colorScheme;
    int tempIndex = currentIndex;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('First day of week',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                      initialItem: currentIndex),
                  itemExtent: 44,
                  selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                    background:
                        cs.primary.withValues(alpha: 0.12),
                  ),
                  onSelectedItemChanged: (i) => tempIndex = i,
                  children: kWeekDayLabels
                      .map((day) => Center(
                            child: Text(day,
                                style: TextStyle(
                                    fontSize: 18,
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w500)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ref
                          .read(startDayProvider.notifier)
                          .setIndex(tempIndex);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Apply',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profileAsync = ref.watch(_profileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final startDayIndex = ref.watch(startDayProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: false),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          final displayName = profile['displayName'] as String? ??
              user?.displayName ??
              'User';
          if (!_editing) _nameController.text = displayName;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ── Avatar ─────────────────────────────────────────
              const SizedBox(height: 20),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: cs.primary,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(displayName,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ),
              if (user?.email != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(user!.email!,
                        style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ),
                ),
              const SizedBox(height: 32),

              // ── Account info card ───────────────────────────────
              Container(
                decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  // Name row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    child: Row(children: [
                      _InfoIcon(
                          icon: Icons.person_outline, color: cs.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Display Name',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              if (_editing)
                                TextField(
                                  controller: _nameController,
                                  autofocus: true,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface),
                                  decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none),
                                  onSubmitted: (_) => _saveName(),
                                )
                              else
                                Text(displayName,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface)),
                            ]),
                      ),
                      if (_editing)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.check,
                                      color: AppColors.available),
                                  onPressed: _saveName),
                          IconButton(
                            icon: Icon(Icons.close,
                                color: cs.onSurface.withValues(alpha: 0.4)),
                            onPressed: () =>
                                setState(() => _editing = false),
                          ),
                        ])
                      else
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                          onPressed: () => setState(() => _editing = true),
                        ),
                    ]),
                  ),
                  Divider(
                      height: 1,
                      indent: 66,
                      color: cs.onSurface.withValues(alpha: 0.08)),
                  // Nickname row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    child: Row(children: [
                      _InfoIcon(
                          icon: Icons.tag,
                          color: AppColors.purple),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nickname',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              if (_editingNickname)
                                TextField(
                                  controller: _nicknameController,
                                  autofocus: true,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface),
                                  decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'How friends call you',
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none),
                                  onSubmitted: (_) => _saveNickname(),
                                )
                              else
                                Text(
                                    (profile['nickname'] as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? profile['nickname'] as String
                                        : 'Not set',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: (profile['nickname'] as String?)
                                                    ?.isNotEmpty ==
                                                true
                                            ? cs.onSurface
                                            : cs.onSurface
                                                .withValues(alpha: 0.4))),
                            ]),
                      ),
                      if (_editingNickname)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _savingNickname
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.check,
                                      color: AppColors.available),
                                  onPressed: _saveNickname),
                          IconButton(
                            icon: Icon(Icons.close,
                                color:
                                    cs.onSurface.withValues(alpha: 0.4)),
                            onPressed: () => setState(
                                () => _editingNickname = false),
                          ),
                        ])
                      else
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                          onPressed: () {
                            _nicknameController.text =
                                (profile['nickname'] as String?) ?? '';
                            setState(() => _editingNickname = true);
                          },
                        ),
                    ]),
                  ),
                  Divider(
                      height: 1,
                      indent: 66,
                      color: cs.onSurface.withValues(alpha: 0.08)),
                  // Email row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(children: [
                      _InfoIcon(
                          icon: Icons.mail_outline,
                          color: AppColors.available),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(user?.email ?? '—',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                            ]),
                      ),
                    ]),
                  ),
                ]),
              ),

              const SizedBox(height: 28),

              // ── Options header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('Options',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.45),
                        letterSpacing: 0.5)),
              ),

              Container(
                decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  // ── Appearance row ──────────────────────────────
                  _OptionsRow(
                    icon: Icons.brightness_medium_outlined,
                    iconColor: AppColors.purple,
                    label: 'Appearance',
                    value: switch (themeMode) {
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                      _ => 'System',
                    },
                    expanded: _appearanceExpanded,
                    onTap: () => setState(() {
                      _appearanceExpanded = !_appearanceExpanded;
                      if (_appearanceExpanded) _datesExpanded = false;
                    }),
                  ),
                  if (_appearanceExpanded) ...[
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.onSurface.withValues(alpha: 0.06)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Row(children: [
                        _ThemeChip(
                          icon: Icons.phone_iphone,
                          label: 'System',
                          selected: themeMode == ThemeMode.system,
                          onTap: () {
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(ThemeMode.system);
                            setState(() => _appearanceExpanded = false);
                          },
                        ),
                        const SizedBox(width: 8),
                        _ThemeChip(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Light',
                          selected: themeMode == ThemeMode.light,
                          onTap: () {
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(ThemeMode.light);
                            setState(() => _appearanceExpanded = false);
                          },
                        ),
                        const SizedBox(width: 8),
                        _ThemeChip(
                          icon: Icons.nightlight_outlined,
                          label: 'Dark',
                          selected: themeMode == ThemeMode.dark,
                          onTap: () {
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(ThemeMode.dark);
                            setState(() => _appearanceExpanded = false);
                          },
                        ),
                      ]),
                    ),
                  ],

                  Divider(
                      height: 1,
                      indent: 66,
                      color: cs.onSurface.withValues(alpha: 0.08)),

                  // ── Dates row ───────────────────────────────────
                  _OptionsRow(
                    icon: Icons.calendar_month_outlined,
                    iconColor: AppColors.info,
                    label: 'Week starts on',
                    value: kWeekDayLabels[startDayIndex],
                    expanded: false,
                    onTap: () =>
                        _showStartDayPicker(context, startDayIndex),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFB0B8C9), size: 20),
                  ),

                  Divider(
                      height: 1,
                      indent: 66,
                      color: cs.onSurface.withValues(alpha: 0.08)),

                  // ── Show app intro ──────────────────────────────
                  _OptionsRow(
                    icon: Icons.lightbulb_outline,
                    iconColor: AppColors.maybe,
                    label: 'Show app intro',
                    value: '',
                    expanded: false,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                          fullscreenDialog: true),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFB0B8C9), size: 20),
                  ),
                ]),
              ),

              const SizedBox(height: 28),

              // ── About header ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('About',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.45),
                        letterSpacing: 0.5)),
              ),

              Container(
                decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  _OptionsRow(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: AppColors.available,
                    label: 'Privacy Policy',
                    value: '',
                    expanded: false,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LegalScreen(
                              document: LegalDocument.privacy)),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFB0B8C9), size: 20),
                  ),
                  Divider(
                      height: 1,
                      indent: 66,
                      color: cs.onSurface.withValues(alpha: 0.08)),
                  _OptionsRow(
                    icon: Icons.description_outlined,
                    iconColor: AppColors.info,
                    label: 'Terms of Service',
                    value: '',
                    expanded: false,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LegalScreen(
                              document: LegalDocument.terms)),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFB0B8C9), size: 20),
                  ),
                  Divider(
                      height: 1,
                      indent: 66,
                      color: cs.onSurface.withValues(alpha: 0.08)),
                  _OptionsRow(
                    icon: Icons.info_outline,
                    iconColor: AppColors.purple,
                    label: 'Version',
                    value: '1.0.0',
                    expanded: false,
                    onTap: () {},
                    trailing: const SizedBox.shrink(),
                  ),
                ]),
              ),

              const SizedBox(height: 28),

              // ── Archived Groups ─────────────────────────────────
              _ArchivedGroupsSection(),

              const SizedBox(height: 20),

              // ── Sign out ────────────────────────────────────────
              InkWell(
                onTap: _signOut,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    _InfoIcon(
                        icon: Icons.logout,
                        color: AppColors.danger),
                    const SizedBox(width: 14),
                    const Text('Sign out',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger)),
                  ]),
                ),
              ),

              const SizedBox(height: 12),

              // ── Delete account ────────────────────────────────────
              InkWell(
                onTap: _deleteAccount,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    _InfoIcon(
                        icon: Icons.delete_forever_outlined,
                        color: AppColors.danger),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delete account',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.danger)),
                          const SizedBox(height: 2),
                          Text('Permanently remove your data',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.55))),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Options row ──────────────────────────────────────────────────────────────

class _OptionsRow extends StatelessWidget {
  const _OptionsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.expanded,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          _InfoIcon(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          trailing ??
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: cs.onSurface.withValues(alpha: 0.35),
                size: 20,
              ),
        ]),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _InfoIcon extends StatelessWidget {
  const _InfoIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : cs.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: cs.primary, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.45)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.45))),
          ]),
        ),
      ),
    );
  }
}

// ─── Archived groups section ──────────────────────────────────────────────────

class _ArchivedGroupsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedGroupsProvider);
    final cs = Theme.of(context).colorScheme;

    return archivedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('Archived Groups',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.45),
                      letterSpacing: 0.5)),
            ),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: groups.asMap().entries.map((entry) {
                  final i = entry.key;
                  final g = entry.value;
                  final isLast = i == groups.length - 1;
                  return Column(children: [
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(group: g)),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: g.emoji != null
                                  ? Text(g.emoji!,
                                      style: const TextStyle(fontSize: 22))
                                  : Text(
                                      g.name.isNotEmpty
                                          ? g.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(g.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.75))),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(groupsNotifierProvider.notifier)
                                .unarchiveGroup(g.id),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Unarchive',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ]),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                          height: 1,
                          indent: 52,
                          color:
                              cs.onSurface.withValues(alpha: 0.08)),
                  ]);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

