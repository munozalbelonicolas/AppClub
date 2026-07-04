import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/providers/session_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/complete_profile_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/pending_approval_screen.dart';
import 'features/auth/presentation/screens/verify_email_screen.dart';
import 'features/player/presentation/screens/register_player_screen.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
  );

  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: JorgeNewberyApp()));
}

class JorgeNewberyApp extends ConsumerWidget {
  const JorgeNewberyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Jorge Newbery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const _AppNavigator(),
    );
  }
}

/// Controls app-level navigation: Splash → Login → Home
class _AppNavigator extends ConsumerStatefulWidget {
  const _AppNavigator();
  @override
  ConsumerState<_AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends ConsumerState<_AppNavigator> {
  bool _splashFinished = false;

  void _onSplashFinished() {
    setState(() => _splashFinished = true);
  }

  void _goToSplashThenLogin() {
    ref.read(currentUserProvider.notifier).state = null;
  }

  void _forceRefresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    if (!_splashFinished) {
      return SplashScreen(
        key: const ValueKey('splash'),
        onFinished: _onSplashFinished,
      );
    }

    final session = ref.watch(currentUserProvider);

    if (session == null) {
      return LoginScreen(
        key: const ValueKey('login'),
        onLogin: () {}, // Handled reactively
      );
    }

    if (!session.emailVerified) {
      return VerifyEmailScreen(
        key: const ValueKey('verify_email'),
        onRefresh: _forceRefresh,
        onSignOut: _goToSplashThenLogin,
      );
    }

    if (session.isRegistrationIncomplete) {
      return CompleteProfileScreen(
        key: const ValueKey('complete_profile'),
        onComplete: _forceRefresh,
        onSignOut: _goToSplashThenLogin,
      );
    }

    if (session.status == 'pending_approval') {
      return PendingApprovalScreen(
        key: const ValueKey('pending_approval'),
        onRefresh: _forceRefresh,
        onSignOut: _goToSplashThenLogin,
      );
    }

    if (session.status == 'pending_children') {
      return Scaffold(
        key: const ValueKey('pending_children'),
        appBar: AppBar(
          title: const Text('Registrar un hijo'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _goToSplashThenLogin,
            ),
          ],
        ),
        body: RegisterPlayerScreen(
          onSuccess: () async {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(session.id)
                .update({'status': 'pending_approval'});
            ref.read(currentUserProvider.notifier).state =
                session.copyWith(status: 'pending_approval');
            await FirebaseFirestore.instance.collection('notifications').add({
              'type': 'new_user_pending',
              'userId': session.id,
              'userName': '${session.name} ${session.lastName}',
              'createdAt': FieldValue.serverTimestamp(),
              'read': false,
            });
            _forceRefresh();
          },
        ),
      );
    }

    return AppShell(
      key: const ValueKey('home'),
      onLogout: _goToSplashThenLogin,
    );
  }
}
