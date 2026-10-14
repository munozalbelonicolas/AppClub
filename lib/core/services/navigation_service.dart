import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  static Future<dynamic>? navigateTo(Widget screen) {
    final state = navigatorKey.currentState;
    if (state == null) {
      // Si el navegador aún no está listo al abrir la app desde la notificación, programamos para el siguiente frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => screen));
      });
      return null;
    }
    return state.push(MaterialPageRoute(builder: (_) => screen));
  }

  static void popToRoot() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}
