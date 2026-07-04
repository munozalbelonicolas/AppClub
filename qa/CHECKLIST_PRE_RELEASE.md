# Checklist Pre-Release

*Debe completarse por QA antes de subir el build a las tiendas (App Store / Play Store).*

- [ ] Las variables de entorno apuntan a PRODUCCIÓN (no staging/dev).
- [ ] Versión y Build Number actualizados en pubspec.yaml (ej. 1.6.2+5).
- [ ] Firebase App Check está activo (Play Integrity / DeviceCheck).
- [ ] Reglas de Firestore y Storage desplegadas (No están en modo prueba).
- [ ] Ejecución exitosa de Smoke Tests en Emulador Android.
- [ ] Ejecución exitosa de Smoke Tests en Simulador iOS.
- [ ] lutter analyze reporta 0 errores.
- [ ] lutter build apk --release compila sin errores.
- [ ] lutter build ipa compila sin errores.
