// ════════════════════════════════════════════════════════════════════════════
// main.dart
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/app_state.dart';
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
      await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
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
//   1. Show SplashScreen (as a direct widget, not a pushed route)
//   2. In initState: run splash timer + wait for Firebase auth in parallel
//   3. When BOTH complete → decide: app (if authed) or PIN (if not)
//
// KEY INSIGHT: SplashScreen is shown as widget content, not as a route.
// _AppGate.build() returns SplashScreen directly. When we're done with
// splash, we just setState(_screen = ...) — no Navigator involved at all.
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

  // Completer that resolves when the splash video finishes
  final Completer<void> _splashCompleter = Completer<void>();

  // ── Called by SplashScreen when video ends ────────────────────────────────
  void _onSplashVideoEnded() {
    if (!_splashCompleter.isCompleted) _splashCompleter.complete();
  }

  // ── Startup: wait for video AND Firebase auth in parallel ─────────────────
  Future<void> _startupSequence() async {
    // Wait for Firebase Auth to emit its first event.
    // On web, currentUser is null synchronously right after initializeApp()
    // because the persisted session is restored from IndexedDB asynchronously.
    // We MUST await authStateChanges().first — never use currentUser directly.
    final authFuture = FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 8), onTimeout: () => null)
        .catchError((_) => null);

    // Wait for the splash video to finish (video fires _onSplashVideoEnded)
    // Also enforce a minimum splash time as safety
    final minSplash = Future.delayed(const Duration(seconds: 3));

    // Wait for BOTH: auth resolved AND splash finished
    final validSession = await SessionManager.instance.isSessionStillValid();
    final results = await Future.wait([
      authFuture,
      Future.any([_splashCompleter.future, Future.delayed(const Duration(seconds: 6))]),
      minSplash,
    ]);

    if (!mounted) return;

    final user = results[0] as User?;
    debugPrint('Startup complete — user: ${user?.email ?? "none"}');

    if (user != null) {
      _initOwnerSession(user);
      if (validSession) {
        ref.read(pinUnlockedProvider.notifier).state = true;
        SessionManager.instance.startWatching(ref);
        _goto(_Screen.app);
      } else {
        _goto(_Screen.pin);
      }
    } else {
      _goto(_Screen.pin);
    }
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
    if (goDirectly) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _initOwnerSession(user);
      ref.read(sessionUserProvider.notifier).state = null;
      ref.read(pinUnlockedProvider.notifier).state = true;
      // Start inactivity watchdog
      SessionManager.instance.startWatching(ref);
      SessionManager.instance.persistUnlocked();
      _goto(_Screen.adminPanel);
    } else {
      _goto(_Screen.pin);
    }
  }

  // ── Init owner session + auto-add staff ───────────────────────────────────
  void _initOwnerSession(User user) {
    if (!CompanySession.isLoggedIn) {
      CompanySession.init(user.uid,
          name: user.displayName ?? user.email ?? '');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final active =
          ref.read(staffProvider).where((s) => s.isActive).toList();
      if (active.isEmpty) {
        ref.read(staffProvider.notifier).add(StaffMember(
          id:          user.uid,
          name:        user.displayName ?? 'Owner',
          phone:       user.phoneNumber ?? '',
          pin:         '0000',
          isActive:    true,
          // Owner gets ALL permissions — same as sessionUser=null (unrestricted)
          permissions: [
            'dashboard', 'transactions', 'customers', 'inventory',
            'load_unload', 'payments', 'reports', 'notifications',
            'settings', 'expenses', 'smart_entry',
          ],
        ));
      }
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
      duration: const Duration(milliseconds: 400),
      child: switch (_screen) {

        // Splash — shown as a direct widget, not a pushed route.
        // onComplete fires when the video finishes → _onSplashVideoEnded.
        // _startupSequence runs in parallel waiting for Firebase auth.
        // The screen only transitions once BOTH are done.
        _Screen.splash => SplashScreen(
            key: const ValueKey('splash'),
            nextScreen: const SizedBox.shrink(), // unused when onComplete set
            onComplete: _onSplashVideoEnded,
          ),

        // PIN screen
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
          ),

        // Main app
        _Screen.app => const MainScaffold(
            key: ValueKey('app'),
          ),
      },
    );
  }
}
