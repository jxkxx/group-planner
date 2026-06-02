import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import '../providers/groups_provider.dart';
import '../widgets/trip_settings.dart';
import '../../../core/design_tokens.dart';

// Same emoji set as create screen
const _emojiCategories = {
  'Travel': ['🏖️', '✈️', '🗺️', '🏝️', '⛰️', '🏔️', '🏕️', '🌍', '🎒', '🧳'],
  'Food & Drink': ['🍕', '🍔', '🍣', '🍝', '🌮', '🍻', '🍷', '☕', '🍰', '🥂'],
  'Activities': ['🎉', '🎮', '⚽', '🎬', '🎵', '🎤', '🎨', '🏖️', '🎲', '🎳'],
  'Sports': ['🏃', '🚴', '🧗', '🏋️', '⛷️', '🏂', '🏄', '🎾', '🏀', '⚾'],
  'Flags': ['🇨🇿', '🇸🇰', '🇺🇸', '🇬🇧', '🇫🇷', '🇩🇪', '🇮🇹', '🇪🇸', '🇯🇵', '🇲🇽'],
  'Other': ['👨‍👩‍👧', '🎂', '💼', '🏠', '🚗', '🎓', '💍', '🎁', '🐶', '⭐'],
};

class EditGroupScreen extends ConsumerStatefulWidget {
  const EditGroupScreen({super.key, required this.group});
  final GroupModel group;

  @override
  ConsumerState<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends ConsumerState<EditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String? _emoji;
  int? _tripLength;
  int? _tripLengthTolerance;
  DateTime? _windowStart;
  DateTime? _windowEnd;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _emoji = widget.group.emoji;
    _tripLength = widget.group.tripLength;
    _tripLengthTolerance = widget.group.tripLengthTolerance;
    _windowStart = widget.group.windowStart;
    _windowEnd = widget.group.windowEnd;
  }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(groupsNotifierProvider.notifier).updateGroup(
            widget.group.id,
            name: _nameController.text.trim(),
            emoji: _emoji,
            tripLength: _tripLength,
            tripLengthTolerance: _tripLengthTolerance,
            windowStart: _windowStart,
            windowEnd: _windowEnd,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
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
    final displayLetter = nameText.isNotEmpty ? nameText[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Group'), centerTitle: false),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
                          : Text(displayLetter,
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
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface),
              decoration: InputDecoration(
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
              onFieldSubmitted: (_) => _save(),
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
                onPressed: _loading ? null : _save,
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
                    : const Text('Save',
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

// ─── Emoji picker sheet (duplicated to keep files self-contained) ────────────

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
                  child: const Text('Remove',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          const SizedBox(height: 8),
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
