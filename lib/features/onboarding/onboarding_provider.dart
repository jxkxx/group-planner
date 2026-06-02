import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSeenKey = 'onboarding_seen';

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => true; // assume seen until loaded

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kSeenKey) ?? false;
  }

  Future<void> markSeen() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  }
}

final onboardingSeenProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
