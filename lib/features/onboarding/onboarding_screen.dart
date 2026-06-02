import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'onboarding_provider.dart';
import '../../core/design_tokens.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  late final List<_PageData> _pages = [
    _PageData(
      icon: Icons.group_outlined,
      iconColor: const Color(0xFF5C6BC0),
      title: 'Find the best date\nfor everyone',
      body:
          'Group Point helps you and your friends agree on a meetup date without endless group chats.',
    ),
    _PageData(
      icon: Icons.group_add_outlined,
      iconColor: AppColors.available,
      title: 'Create or join\na group',
      body:
          'Start a new group or join one with a 6-character invite code shared by a friend.',
    ),
    _PageData(
      icon: Icons.calendar_today_outlined,
      iconColor: AppColors.maybe,
      title: 'Mark your\navailability',
      body:
          'Tap any date and pick a status: Available, Likely, Maybe, or Unavailable. Your availability is shared with all your groups automatically — you can override it for any group if needed.',
    ),
    _PageData(
      icon: Icons.star_outline_rounded,
      iconColor: AppColors.accent,
      title: 'See the best\ndate together',
      body:
          'We automatically suggest the date that works for the most people — no spreadsheets, no fuss.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                const Spacer(),
                if (!isLast)
                  TextButton(
                    onPressed: _finish,
                    child: Text('Skip',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Action button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(isLast ? 'Get Started' : 'Continue',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  _PageData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});
  final _PageData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon bubble
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              color: data.iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 64, color: data.iconColor),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.6,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
