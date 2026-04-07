// ════════════════════════════════════════════════════════════════════════════
// main.dart
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/staff_provider.dart';
import 'core/providers/app_state.dart'
    show
        customersProvider,
        transactionsProvider,
        inventoryProvider,
        ledgerProvider,
        dayLogProvider,
        loadUnloadProvider;
import 'core/services/company_session.dart';
import 'core/services/firebase_config.dart';
import 'core/services/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/admin_panel_screen.dart';
import 'features/company_login_screen.dart';
import 'features/main_scaffold.dart';
import 'features/pin_lock_screen.dart';
import 'features/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('--- DEPLOYMENT DEBUG ---');
  debugPrint('Build Date: 2026-03-24 12:00 (Manual Check)');
  
  try {
    debugPrint('Firebase: Initializing for ${FirebaseConfig.projectId}...');
    if (FirebaseConfig.isConfigured) {
      debugPrint('Firebase: Config looks OK (API Key found)');
      debugPrint('Firebase: Database URL = [${FirebaseConfig.databaseUrl}]');
      
      // Mask the key for safe logging (e.g. AIza...2ho)
      final key = FirebaseConfig.apiKey;
      final appId = FirebaseConfig.appId;
      final maskedKey = key.length > 8 ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}' : 'INVALID';
      final maskedAppId = appId.length > 8 ? '${appId.substring(0, 4)}...${appId.substring(appId.length - 4)}' : 'INVALID';
      
      debugPrint('Firebase: Masked API Key = $maskedKey');
      debugPrint('Firebase: Masked App ID  = $maskedAppId');
      debugPrint('Firebase: Auth Domain    = ${FirebaseConfig.authDomain}');
      
      if (FirebaseConfig.appId.length < 30) {
        debugPrint('Firebase: ⚠️ WARNING: App ID seems too short! Please verify it in GitHub Secrets.');
      }
    } else {
      debugPrint('Firebase: ⚠️ WARNING: Missing API Key or Project ID in build config!');
    }

    // Use a try-catch specifically for initialization to provide more context
    try {
      if (FirebaseConfig.isConfigured) {
        debugPrint('Firebase: Initializing with dart-define options');
        await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
      } else if (!kIsWeb) {
        debugPrint('Firebase: No dart-define config found; attempting native platform initialization');
        await Firebase.initializeApp();
      } else {
        debugPrint('Firebase: Missing web configuration and no native fallback available');
        throw StateError('Firebase web configuration is missing');
      }
      debugPrint('Firebase: App initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization CRITICAL error: $e');
      rethrow; // Don't continue if init fails
    }

    // Lazily initialize database connection. 
    // We don't await .info/connected here because it can hang on some networks/Web builds.
    FirebaseDatabase.instanceFor(
        app: Firebase.app(), databaseURL: FirebaseConfig.databaseUrl);
    debugPrint('Firebase: Database connection prepared');
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Pre-init CompanySession if user already signed in (sync check after init)
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
    final settings  = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    return ActivityDetector(
      child: MaterialApp(
        title: settings.appName,
        debugShowCheckedModeBanner: false,
        theme:     AppTheme.light(settings.accentColor),
        darkTheme: AppTheme.dark(settings.accentColor),
        themeMode: themeMode,
        home: const _AppGate(),
      ),
    );
  }
}

// ── Activity Detector ─────────────────────────────────────────────────────────
// Wraps the entire app in a transparent GestureDetector (HitTestBehavior.translucent
// so it never blocks child taps) and records activity on any pointer event.
// This feeds SessionManager's inactivity watchdog.
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
//
// Clean state machine — _screen drives what build() returns.
// NO Navigator.push anywhere. No bridge widgets. No race conditions.
//
// STARTUP SEQUENCE:
//   1. Initialize Firebase and auth state
//   2. Show PIN screen immediately
//   3. Owner / staff login begins without splash animation
// ══════════════════════════════════════════════════════════════════════════════
enum _Screen { splash, pin, adminPortal, adminPanel, app }

class _AppGate extends ConsumerStatefulWidget {
  const _AppGate();
  @override
  ConsumerState<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<_AppGate> {
  _Screen _screen = _Screen.splash;

  @override
  void initState() {
    super.initState();
    _startupSequence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache the default logo asset (fallback when no custom logo is configured)
    precacheImage(
        const AssetImage('assets/images/mrwater_logo.png'), context);
  }

  // Completer that resolves when the splash animation finishes
  final Completer<void> _splashCompleter = Completer<void>();

  // ── Called by SplashScreen when animation ends ───────────────────────────
  void _onSplashVideoEnded() {
    if (!_splashCompleter.isCompleted) _splashCompleter.complete();
  }

  // ── Startup: wait for auth and the splash animation in parallel ────────
  Future<void> _startupSequence() async {
    final authFuture = FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 8), onTimeout: () => null)
        .catchError((_) => null);

    final minSplash = Future.delayed(const Duration(seconds: 2));

    final results = await Future.wait([
      authFuture,
      Future.any([_splashCompleter.future, Future.delayed(const Duration(seconds: 4))]),
      minSplash,
    ]);

    if (!mounted) return;
    final user = results[0] as User?;
    debugPrint('Startup complete — user: ${user?.email ?? "none"}');
    _goto(_Screen.pin);
  }

  // ── Safe setState ─────────────────────────────────────────────────────────
  void _goto(_Screen s) {
    if (!mounted) return;
    setState(() => _screen = s);
  }

  // ── PIN screen unlocked ───────────────────────────────────────────────────
  void _onPinUnlocked(bool isOwner) {
    if (!mounted) return;
    if (isOwner) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _initOwnerSession(user);
      ref.read(sessionUserProvider.notifier).state = null;
    }
    ref.read(pinUnlockedProvider.notifier).state = true;
    // Start inactivity watchdog — will auto-lock after kInactivityTimeout idle
    SessionManager.instance.startWatching(ref);
    SessionManager.instance.persistUnlocked();
    _goto(_Screen.app);
  }

  // ── Long-press logo → open hidden admin portal ────────────────────────────
  void _onOpenAdminPortal() => _goto(_Screen.adminPortal);

  // ── Admin portal authentication complete ─────────────────────────────────
  void _onAdminAuthenticated({required bool goDirectly}) {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _initOwnerSession(user);
    ref.read(sessionUserProvider.notifier).state = null;
    ref.read(pinUnlockedProvider.notifier).state = true;
    // Start inactivity watchdog
    SessionManager.instance.startWatching(ref);
    SessionManager.instance.persistUnlocked();
    if (goDirectly) {
      _goto(_Screen.adminPanel);
    } else {
      _goto(_Screen.app);
    }
  }

  // ── Init owner session ────────────────────────────────────────────────────
  // Always updates CompanySession to the current user's UID and reinitialises
  // ALL data providers so they stream from the correct company's Firebase node.
  //
  // IMPORTANT: we always call CompanySession.init() unconditionally — never
  // guarded by isLoggedIn. If Company A was active and Company B now logs in,
  // the session must switch to Company B immediately so every provider reads
  // from companies/{B}/... instead of companies/{A}/...
  //
  // Does NOT create any user records — that is done ONCE by
  // CompanyLoginScreen._ensureOwnerRecord() on first sign-up only.
  void _initOwnerSession(User user) {
    // Always update — this is the critical fix for multi-company switching.
    CompanySession.init(user.uid,
        name: user.displayName ?? user.email ?? '');

    // Reinit ALL providers so they cancel their old Firebase streams and
    // open new ones scoped to the current company UID.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(staffProvider.notifier).reinit();
      ref.read(settingsProvider.notifier).reinit();
      ref.read(customersProvider.notifier).reinit();
      ref.read(transactionsProvider.notifier).reinit();
      ref.read(inventoryProvider.notifier).reinit();
      ref.read(ledgerProvider.notifier).reinit();
      ref.read(dayLogProvider.notifier).reinit();
      ref.read(loadUnloadProvider.notifier).reinit();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Watch pinUnlockedProvider — main_scaffold sets this to false on logout.
    // When it becomes false while we're showing the app, switch to PIN screen.
    final pinUnlocked = ref.watch(pinUnlockedProvider);
    if (!pinUnlocked && _screen == _Screen.app) {
      // Use postFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goto(_Screen.pin);
      });
    }

    return AnimatedSwitcher(
      duration: Duration.zero,
      child: switch (_screen) {


        // PIN screen
        _Screen.splash => SplashScreen(
            key: const ValueKey('splash'),
            nextScreen: const SizedBox.shrink(),
            onComplete: _onSplashVideoEnded,
          ),
        _Screen.pin => PinLockScreen(
            key: const ValueKey('pin'),
            onUnlocked:        _onPinUnlocked,
            onOpenAdminPortal: _onOpenAdminPortal,
          ),

        // Hidden admin portal
        _Screen.adminPortal => CompanyLoginScreen(
            key: const ValueKey('admin'),
            onAuthenticated: _onAdminAuthenticated,
            onBack: () => _goto(_Screen.pin),
          ),

        // Owner admin panel
        _Screen.adminPanel => AdminPanelScreen(
            key: const ValueKey('admin_panel'),
            onBack: () => _goto(_Screen.app),
            onSignOut: () => _goto(_Screen.pin),
          ),

        // Main app
        _Screen.app => const MainScaffold(
            key: ValueKey('app'),
          ),
      },
    );
  }
}
