import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme_provider.dart';
import 'core/design_tokens.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/groups/screens/groups_screen.dart';
import 'features/availability/screens/availability_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/onboarding/onboarding_provider.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load persisted settings before first frame
  final container = ProviderContainer();
  await Future.wait([
    container.read(themeModeProvider.notifier).load(),
    container.read(startDayProvider.notifier).load(),
    container.read(onboardingSeenProvider.notifier).load(),
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
  ));

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboardingSeen = ref.watch(onboardingSeenProvider);

    return MaterialApp(
      title: 'Group Point',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MainShell();
          }
          // Logged out: show onboarding first if not seen
          if (!onboardingSeen) {
            return const OnboardingScreen();
          }
          return const SignInScreen();
        },
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.brandPrimary,
    brightness: brightness,
  );
  final cs = base.copyWith(
    surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
    surfaceContainerHighest:
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
    primary: isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary,
  );

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      iconTheme: IconThemeData(
          color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      margin: EdgeInsets.zero,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor:
          isDark ? AppColors.darkBottomNav : AppColors.lightSurface,
      selectedItemColor:
          isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary,
      unselectedItemColor:
          isDark ? AppColors.darkUnselected : AppColors.lightUnselected,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFEEF0F5),
      thickness: 1,
      space: 0,
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    GroupsScreen(),
    AvailabilityScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
                color: cs.onSurface.withValues(alpha: 0.08), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Groups',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Availability',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
