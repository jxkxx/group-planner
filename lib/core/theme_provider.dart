import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

const _kThemeKey = 'theme_mode';
const _kStartDayKey = 'start_day_of_week';

// ─── Theme mode ───────────────────────────────────────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeKey);
    state = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      },
    );
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ─── Start day of week ────────────────────────────────────────────────────────

// Days ordered for the picker (index 0 = Monday, 6 = Sunday)
const kWeekDayLabels = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

const _kDayToStarting = [
  StartingDayOfWeek.monday,
  StartingDayOfWeek.tuesday,
  StartingDayOfWeek.wednesday,
  StartingDayOfWeek.thursday,
  StartingDayOfWeek.friday,
  StartingDayOfWeek.saturday,
  StartingDayOfWeek.sunday,
];

class StartDayNotifier extends Notifier<int> {
  // index into kWeekDayLabels; default = 0 (Monday)
  @override
  int build() => 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_kStartDayKey) ?? 0;
  }

  Future<void> setIndex(int index) async {
    state = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStartDayKey, index);
  }

  StartingDayOfWeek get startingDayOfWeek => _kDayToStarting[state];
}

final startDayProvider =
    NotifierProvider<StartDayNotifier, int>(StartDayNotifier.new);

// Convenience: just the StartingDayOfWeek value
final startingDayOfWeekProvider = Provider<StartingDayOfWeek>((ref) {
  final index = ref.watch(startDayProvider);
  return _kDayToStarting[index];
});
