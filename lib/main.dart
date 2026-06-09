import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'app/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const JorgeNewberyApp());
}

class JorgeNewberyApp extends StatelessWidget {
  const JorgeNewberyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jorge Newbery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AppNavigator(),
    );
  }
}

/// Controls app-level navigation: Splash → Login → Home
class _AppNavigator extends StatefulWidget {
  const _AppNavigator();
  @override
  State<_AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<_AppNavigator> {
  _AppScreen _currentScreen = _AppScreen.splash;

  void _goToLogin() {
    setState(() => _currentScreen = _AppScreen.login);
  }

  void _goToHome() {
    setState(() => _currentScreen = _AppScreen.home);
  }

  void _goToSplashThenLogin() {
    setState(() => _currentScreen = _AppScreen.login);
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
    switch (_currentScreen) {
      case _AppScreen.splash:
        return SplashScreen(
          key: const ValueKey('splash'),
          onFinished: _goToLogin,
        );
      case _AppScreen.login:
        return LoginScreen(
          key: const ValueKey('login'),
          onLogin: _goToHome,
        );
      case _AppScreen.home:
        return AppShell(
          key: const ValueKey('home'),
          onLogout: _goToSplashThenLogin,
        );
    }
  }
}

enum _AppScreen { splash, login, home }
