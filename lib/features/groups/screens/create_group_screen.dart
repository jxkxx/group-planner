import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/groups_provider.dart';
import '../widgets/trip_settings.dart';
import 'group_detail_screen.dart';
import '../../../core/design_tokens.dart';

// Curated emoji set: most-used for group naming
const _emojiCategories = {
  'Travel': ['🏖️', '✈️', '🗺️', '🏝️', '⛰️', '🏔️', '🏕️', '🌍', '🎒', '🧳'],
  'Food & Drink': ['🍕', '🍔', '🍣', '🍝', '🌮', '🍻', '🍷', '☕', '🍰', '🥂'],
  'Activities': ['🎉', '🎮', '⚽', '🎬', '🎵', '🎤', '🎨', '🏖️', '🎲', '🎳'],
  'Sports': ['🏃', '🚴', '🧗', '🏋️', '⛷️', '🏂', '🏄', '🎾', '🏀', '⚾'],
  'Flags': ['🇨🇿', '🇸🇰', '🇺🇸', '🇬🇧', '🇫🇷', '🇩🇪', '🇮🇹', '🇪🇸', '🇯🇵', '🇲🇽'],
  'Other': ['👨‍👩‍👧', '🎂', '💼', '🏠', '🚗', '🎓', '💍', '🎁', '🐶', '⭐'],
};

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _emoji;
  int? _tripLength;
  int? _tripLengthTolerance;
  DateTime? _windowStart;
  DateTime? _windowEnd;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmojiPickerSheet(current: _emoji),
    );
    if (result != null && mounted) {
      setState(() => _emoji = result.isEmpty ? null : result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final group = await ref
          .read(groupsNotifierProvider.notifier)
          .createGroup(
            _nameController.text.trim(),
            emoji: _emoji,
            tripLength: _tripLength,
            tripLengthTolerance: _tripLengthTolerance,
            windowStart: _windowStart,
            windowEnd: _windowEnd,
          );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create group: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nameText = _nameController.text.trim();
    final displayEmoji =
        _emoji ?? (nameText.isNotEmpty ? nameText[0].toUpperCase() : '?');

    return Scaffold(
      appBar: AppBar(title: const Text('Create Group'), centerTitle: false),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar + emoji picker
            Center(
              child: GestureDetector(
                onTap: _pickEmoji,
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(children: [
                    Center(
                      child: _emoji != null
                          ? Text(_emoji!, style: const TextStyle(fontSize: 48))
                          : Text(displayEmoji,
                              style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 42)),
                    ),
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _pickEmoji,
                child: Text(_emoji == null ? 'Choose emoji' : 'Change emoji',
                    style: TextStyle(
                        color: cs.primary, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),

            Text('Group name',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g. Weekend Crew',
                hintStyle: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.35), fontSize: 16),
                filled: true,
                fillColor: cs.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.danger, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.danger, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a group name.';
                }
                if (v.trim().length > 50) {
                  return 'Name must be 50 characters or fewer.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 20),
            TripSettings(
              initialTripLength: _tripLength,
              initialTripLengthTolerance: _tripLengthTolerance,
              initialWindowStart: _windowStart,
              initialWindowEnd: _windowEnd,
              onChanged: (len, tol, start, end) {
                setState(() {
                  _tripLength = len;
                  _tripLengthTolerance = tol;
                  _windowStart = start;
                  _windowEnd = end;
                });
              },
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Group',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Emoji picker sheet ───────────────────────────────────────────────────────

class _EmojiPickerSheet extends StatelessWidget {
  const _EmojiPickerSheet({this.current});
  final String? current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(children: [
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
                child: Text('Choose Emoji',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ),
              if (current != null)
                TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  child: Text('Remove',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          const SizedBox(height: 8),

          // Emoji grid
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: _emojiCategories.entries.map((entry) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Text(entry.key,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface.withValues(alpha: 0.5),
                                letterSpacing: 0.5)),
                      ),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: entry.value.map((emoji) {
                          final isSelected = current == emoji;
                          return GestureDetector(
                            onTap: () => Navigator.pop(context, emoji),
                            child: Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary.withValues(alpha: 0.15)
                                    : cs.onSurface.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: isSelected
                                    ? Border.all(
                                        color: cs.primary, width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 28)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ]);
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}
