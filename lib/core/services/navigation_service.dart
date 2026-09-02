import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  static Future<dynamic>? navigateTo(Widget screen) {
    final state = navigatorKey.currentState;
    if (state == null) return null;
    return state.push(MaterialPageRoute(builder: (_) => screen));
  }

  static void popToRoot() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}
