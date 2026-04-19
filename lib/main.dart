// ════════════════════════════════════════════════════════════════════════════
// main.dart  — FIX v2: warm-resume session check + Firebase offline persistence
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/staff_member.dart';
import 'core/models/user_role.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/staff_provider.dart';
import 'core/services/company_session.dart';
import 'core/services/rtdb_user_datasource.dart';
import 'core/services/firebase_config.dart';
import 'core/services/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/admin_panel_screen.dart';
import 'features/modern_company_login_screen.dart';
import 'features/main_scaffold.dart';
import 'features/modern_pin_lock_screen.dart';
import 'features/modern_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('--- DEPLOYMENT DEBUG ---');
  debugPrint('Build Date: 2026-04-18 (FIX v2)');

  try {
    debugPrint('Firebase: Initializing for ${FirebaseConfig.projectId}...');
    if (FirebaseConfig.isConfigured) {
      debugPrint('Firebase: Config looks OK (API Key found)');
      debugPrint('Firebase: Database URL = [${FirebaseConfig.databaseUrl}]');

      final key = FirebaseConfig.apiKey;
      final appId = FirebaseConfig.appId;
      final maskedKey = key.length > 8
          ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}'
          : 'INVALID';
      final maskedAppId = appId.length > 8
          ? '${appId.substring(0, 4)}...${appId.substring(appId.length - 4)}'
          : 'INVALID';

      debugPrint('Firebase: Masked API Key = $maskedKey');
      debugPrint('Firebase: Masked App ID  = $maskedAppId');
      debugPrint('Firebase: Auth Domain    = ${FirebaseConfig.authDomain}');

      if (FirebaseConfig.appId.length < 30) {
        debugPrint(
            'Firebase: ⚠️ WARNING: App ID seems too short! Please verify it in GitHub Secrets.');
      }
    } else {
      debugPrint(
          'Firebase: ⚠️ WARNING: Missing API Key or Project ID in build config!');
    }

    try {
      if (FirebaseConfig.isConfigured) {
        debugPrint('Firebase: Initializing with dart-define options');
        await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
      } else if (!kIsWeb) {
        debugPrint(
            'Firebase: No dart-define config found; attempting native platform initialization');
        await Firebase.initializeApp();
      } else {
        debugPrint(
            'Firebase: Missing web configuration and no native fallback available');
        throw StateError('Firebase web configuration is missing');
      }
      debugPrint('Firebase: App initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization CRITICAL error: $e');
      rethrow;
    }

    FirebaseDatabase.instanceFor(
        app: Firebase.app(), databaseURL: FirebaseConfig.databaseUrl);
    debugPrint('Firebase: Database connection prepared');

    // FIX: Enable offline persistence so delivery staff can work without internet.
    // RTDB queues writes and serves reads from cache when offline.
    // Mobile only — web persistence has different API and is opt-in separately.
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      // 10 MB cache — enough to hold customers + transactions for a typical day
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
      debugPrint('Firebase: Offline persistence ENABLED (10 MB cache)');
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    CompanySession.init(currentUser.uid,
        name: currentUser.displayName ?? currentUser.email ?? '');
    debugPrint('CompanySession pre-init: ${currentUser.email}');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const ProviderScope(child: MrWaterApp()));
}

class MrWaterApp extends ConsumerWidget {
  const MrWaterApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    return ActivityDetector(
      child: MaterialApp(
        title: settings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(settings.accentColor),
        darkTheme: AppTheme.dark(settings.accentColor),
        themeMode: themeMode,
        home: const _AppGate(),
      ),
    );
  }
}

// ── Activity Detector ─────────────────────────────────────────────────────────
class ActivityDetector extends StatelessWidget {
  final Widget child;
  const ActivityDetector({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => SessionManager.instance.recordActivity(),
        onPointerMove: (_) => SessionManager.instance.recordActivity(),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// APP GATE
// ══════════════════════════════════════════════════════════════════════════════
enum _Screen { splash, pin, adminPortal, adminPanel, app }

class _AppGate extends ConsumerStatefulWidget {
  const _AppGate();
  @override
  ConsumerState<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<_AppGate> {
  _Screen _screen = _Screen.splash;

  // FIX: flag set when the lock was triggered by inactivity (not explicit sign-out).
  // Kept for future use when ModernPinLockScreen adds a lockedDueToInactivity param.
  // ignore: unused_field
  bool _lockedDueToInactivity = false;

  @override
  void initState() {
    super.initState();
    _startupSequence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/mrwater_logo.png'), context);
  }

  final Completer<void> _splashCompleter = Completer<void>();

  void _onSplashVideoEnded() {
    if (!_splashCompleter.isCompleted) _splashCompleter.complete();
  }

  Future<void> _startupSequence() async {
    final authFuture = FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 8), onTimeout: () => null)
        .catchError((_) => null);

    final minSplash = Future.delayed(const Duration(seconds: 2));

    final results = await Future.wait([
      authFuture,
      Future.any([
        _splashCompleter.future,
        Future.delayed(const Duration(seconds: 4))
      ]),
      minSplash,
    ]);

    if (!mounted) return;
    final user = results[0] as User?;
    debugPrint('Startup complete — user: ${user?.email ?? "none"}');

    // FIX: Check if a recent session is still valid before forcing PIN screen.
    // This prevents re-showing the PIN on every warm resume within 5 minutes.
    if (user != null) {
      final sessionValid = await SessionManager.instance.isSessionStillValid();
      if (sessionValid && mounted) {
        debugPrint('[AppGate] Warm resume — session still valid, skipping PIN');
        _initOwnerSession(user);
        ref.read(pinUnlockedProvider.notifier).state = true;
        SessionManager.instance.startWatching(ref);
        _goto(_Screen.app);
        return;
      }
    }

    _goto(_Screen.pin);
  }

  void _goto(_Screen s) {
    if (!mounted) return;
    setState(() => _screen = s);
  }

  void _onPinUnlocked(bool isOwner) {
    if (!mounted) return;
    if (isOwner) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _initOwnerSession(user);
      ref.read(sessionUserProvider.notifier).state = null;
    }
    ref.read(pinUnlockedProvider.notifier).state = true;
    // FIX: persist unlock timestamp so warm-resume skips PIN within 5 minutes
    SessionManager.instance.persistUnlocked();
    SessionManager.instance.startWatching(ref);
    // Clear inactivity flag on successful unlock
    setState(() => _lockedDueToInactivity = false);
    _goto(_Screen.app);
  }

  void _onOpenAdminPortal() => _goto(_Screen.adminPortal);

  void _onAdminAuthenticated({required bool goDirectly}) {
    _onPinUnlocked(true);
    if (goDirectly) {
      _goto(_Screen.adminPanel);
    }
  }

  void _initOwnerSession(User user) {
    if (!CompanySession.isLoggedIn) {
      CompanySession.init(user.uid,
          name: user.displayName ?? user.email ?? '');
    }
    ref.read(staffProvider.notifier).reinit();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final existing = await RTDBUserDataSource.instance
          .getUser(CompanySession.companyId, user.uid);

      if (existing == null) {
        ref.read(staffProvider.notifier).add(StaffMember(
          id: user.uid,
          name: user.displayName ?? 'Owner',
          phone: user.phoneNumber ?? '',
          pin: '',
          isActive: true,
          role: UserRole.owner,
          permissions: const [
            'dashboard', 'transactions', 'customers', 'inventory',
            'load_unload', 'payments', 'reports', 'notifications',
            'settings', 'expenses', 'smart_entry',
          ],
        ));
      }
    });
  }

  // Called by SessionManager inactivity watchdog — sets inactivity flag first.
  // ignore: unused_element
  void _lockDueToInactivity() {
    setState(() => _lockedDueToInactivity = true);
    SessionManager.instance.lock(ref);
    _goto(_Screen.pin);
  }

  @override
  Widget build(BuildContext context) {
    final pinUnlocked = ref.watch(pinUnlockedProvider);

    final effectiveScreen =
        (!pinUnlocked && _screen == _Screen.app) ? _Screen.pin : _screen;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (effectiveScreen) {
        _Screen.splash => ModernSplashScreen(
            key: const ValueKey('splash'),
            nextScreen: const SizedBox.shrink(),
            onComplete: _onSplashVideoEnded,
          ),
        _Screen.pin => ModernPinLockScreen(
            key: const ValueKey('pin'),
            onUnlocked: _onPinUnlocked,
            onOpenAdminPortal: _onOpenAdminPortal,
          ),
        _Screen.adminPortal => ModernCompanyLoginScreen(
            key: const ValueKey('admin'),
            onAuthenticated: _onAdminAuthenticated,
            onBack: () => _goto(_Screen.pin),
          ),
        _Screen.adminPanel => AdminPanelScreen(
            key: const ValueKey('admin_panel'),
            onBack: () => _goto(_Screen.app),
            onSignOut: () => _goto(_Screen.pin),
          ),
        _Screen.app => const MainScaffold(
            key: ValueKey('app'),
          ),
      },
    );
  }
}
