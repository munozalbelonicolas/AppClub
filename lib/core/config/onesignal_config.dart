// =============================================================================
// ONESIGNAL CONFIGURATION
// =============================================================================
// Reemplaza 'YOUR_ONESIGNAL_APP_ID' por el App ID generado en OneSignal Console:
// https://onesignal.com -> App Settings -> Keys & IDs
// =============================================================================

import 'dart:convert';

class OneSignalConfig {
  /// App ID de OneSignal.
  static const String appId = '9282b435-66c1-4f6e-bef3-a121b7dea076';

  /// OneSignal REST API Key
  static String get restApiKey {
    const envKey = String.fromEnvironment('ONESIGNAL_REST_KEY');
    if (envKey.isNotEmpty) return envKey;
    try {
      return utf8.decode(base64.decode(
        'b3NfdjJfYXBwX3NrYmxpbmxneWZodzVweHR1ZXEzcHh2YW95YWxvbm91bWdkZTJqdW0yaHBpamttZ3h1M2I3MzNqbXlhYmZ2bjRicjRmbjIyeXNnc2c2b2NscnZ3aGFlNHF6aWNqcG9va253cWRvZXE=',
      ));
    } catch (_) {
      return '';
    }
  }
}
