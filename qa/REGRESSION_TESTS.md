# Regression Tests

*Ejecutar previo a un Release Mayor (ej. v1.7.0). Cubre edge cases y flujos completos.*

## Modulo: Autenticación
- [ ] Recuperación de contraseña envía email.
- [ ] Expiración de sesión (forzar revocación de token) maneja error y desloguea.
- [ ] Bloqueo tras N intentos fallidos (si aplica).

## Modulo: Roles y Permisos (Seguridad)
- [ ] Cuenta Jugador NO ve el botón de "Crear Evento".
- [ ] Cuenta Jugador NO puede eliminar un Producto de Tienda.
- [ ] Cuenta DT (Entrenador) puede ver reportes pero NO puede borrar usuarios.
- [ ] Cuenta Admin (Directivo) tiene acceso total.

## Modulo: Conectividad y Edge Cases
- [ ] Llenar formulario de Registro, apagar WiFi, presionar "Guardar" -> Mensaje de error controlado.
- [ ] Activar modo Avión con la app abierta -> UI muestra "Sin Internet".
- [ ] Subir imagen pesada (>5MB) a recibos -> Debe fallar o comprimir.
- [ ] Inputs inválidos (strings larguísimos, inyección de caracteres especiales) manejados correctamente por el UI.
