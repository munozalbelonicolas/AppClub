# 03 · Guía de Testing Manual y Detección de Funcionalidad Muerta

> Guía práctica para ejecutar pruebas manuales y detectar **funcionalidad muerta** (screens inaccesibles, botones sin acción, datos que se escriben pero nunca se leen, features simuladas).
> Complementa los scripts de `02_SCRIPT_DE_PRUEBAS_POR_ROL.md`.

---

## 1. Método de trabajo recomendado

| Paso | Actividad |
|---|---|
| 1 | Preparar **cuentas de prueba por rol** (directivo, secretario, dt, tutor, jugador, socio) y datos semilla en Firestore. |
| 2 | Ejecutar los **smoke tests** (`qa/SMOKE_TESTS.md`) en cada build nuevo. |
| 3 | Ejecutar los **scripts por tarea** (`02_SCRIPT_DE_PRUEBAS_POR_ROL.md`) en cada release. |
| 4 | Ejecutar la **auditoría de funcionalidad muerta** (sección 5 de esta guía) periódicamente o tras grandes refactors. |
| 5 | Registrar hallazgos con la plantilla de bug (`qa/BUG_TEMPLATE.md`). |

**Ambientes de prueba:**
- Emulador Android / simulador iOS + dispositivo físico (importante para push y cámara).
- Consola de Firebase (Firestore, Auth, Functions, Cloudinary) abierta para verificar escrituras.
- Red: probar con y sin conexión (modo avión) para tolerancia a fallos.

---

## 2. Cheat-sheet de accesos por rol (para probar rápido)

Ruta de acceso a cada feature (para saber dónde hacer clic):

| Feature | Ruta de acceso |
|---|---|
| Feed de novedades | Tab Inicio |
| Calendario | Tab Calendario |
| Formación/Convocatoria | Tab Formación |
| Noticias (comunicados) | Tab Noticias |
| Tienda | Tab Tienda |
| Settings | Tab Más |
| Mi Perfil | Más → Mi Cuenta / Mi Perfil |
| Mis Hijos | Más → Mis Hijos (no jugador) |
| Buzón | Más → Buzón |
| Resultados / Fixture / Informe Liga | Más → (sección Deportivo) |
| Consola del Director | Más → Consola del Director (admin) |
| Sistema de Cumpleaños | Más → Sistema de Cumpleaños (admin) |
| Sponsors | Más → Gestión de Sponsors (admin) |
| Competiciones (Club/Goleadores) | Más → Competiciones y Rivalidades (admin/DT) |
| Panel DT | Más → Herramientas de DT → Panel DT (solo DT) |
| Asistencia (edición) | Quick action Home o Panel DT (DT/admin) |
| Cuotas (pago) | Quick action Home (tutor) |
| Carnet / Dashboard socio | Tabs del shell socio |

---

## 3. Checklist de "funcionalidad viva" (todo rol)

Cuando pruebes cualquier pantalla, confirma que la funcionalidad:
1. **Es alcanzable**: hay una ruta de navegación visible (tab, menú, botón o quick action) que llega a la pantalla. ✅
2. **Hace algo real**: al tocar botones/gestos se produce un efecto observable (escritura en Firestore, navegación, cambio de UI). ✅
3. **Persiste**: si la acción guarda datos, se mantienen tras cerrar/reabrir la app y son visibles en Firebase Console. ✅
4. **Responde a permisos**: un usuario sin el rol adecuado NO ve la acción, o ve un mensaje de error/bloqueo. ✅
5. **No es mock**: los datos mostrados provienen de Firestore (u otra fuente real) y no de valores fijos en código. ✅

Si alguna de las 5 condiciones falla → **candidato a funcionalidad muerta/simulada**. Regístralo.

---

## 4. Cómo detectar funcionalidad muerta — manual

### 4.1 Técnica del "recorrido de navegación" (mapa de pantallas)
1. Para cada pantalla del inventario (`01_ROLES_Y_FUNCIONALIDADES.md`), anota **todas las formas de llegar** (tab, quick action, menú, push desde otra pantalla).
2. Ejecuta la app e intenta llegar a cada pantalla con **cada rol aplicable**.
3. Marca **"INACCESIBLE"** si no existe ninguna ruta real (no cuenta navegar con "back", deep links no documentados ni flujos ocultos).

**Pantallas a auditar por inaccesibilidad (hallazgo de código):**
- `PlayerProfileScreen` (`features/player/presentation/screens/player_profile_screen.dart`) — **sin ninguna referencia** en el código: no hay `Navigator.push` ni menú. Verifícalo manualmente: debería ser inaccesible desde cualquier rol.

### 4.2 Técnica de "botones muertos"
Durante el recorrido, toca **todos** los elementos interactivos (botones, iconos, filas, FAB, toggles, long-press) y anota si responden. Casos conocidos a verificar:
- Panel DT → botones **"Convocatoria"** y **"Notas"** (`coach_dashboard_screen.dart:307,331`) — `onTap` vacío.
- Panel DT → tarjetas **"Puntos 13 / Posición 1° / Partidos 5"** — hardcodeadas, no cambian con datos reales.
- Home → **"Payment Status"** y **"Player Quick Stats"** — nunca se renderizan (variables `const null`).
- Settings → **toggles de notificación** — cambian visualmente pero NO persisten ni tienen efecto.
- Tab Formación → para un tutor/jugador, el badge **"CONVOCATORIA"** es decorativo (no navega).

### 4.3 Técnica de "escritura sin lectura" (datos huérfanos)
Con Firebase Console abierta:
1. Realiza una acción que escribe datos (crear informe de DT, marcar asistencia, etc.).
2. Busca en Firestore la colección destino.
3. Luego busca **qué pantalla lee** esa colección (usa búsqueda en el código, o grep de la colección).

**Caso conocido:**
- **Informes de DT a Directiva**: el DT escribe en `coach_reports` (`create_coach_report_screen.dart`), pero **ninguna pantalla lee** esa colección → la directiva no puede ver los informes. La funcionalidad está "a medio construir".

### 4.4 Técnica de "features simuladas / mock"
Compara lo que ves en pantalla con lo que hay en Firestore:
- **Informe de Liga**: el "adjuntar archivo" genera una URL falsa (`https://example.com/...`) en lugar de subir el archivo. Prueba descargar el adjunto → fallará.
- **Stats del Panel DT**: valores fijos.
- **Subida de imágenes**: en general va a Cloudinary (no a Firebase Storage). Verifica que el storage de Firebase no se usa (si ves reglas de `storage.rules` sin uso, es infraestructura muerta).

### 4.5 Técnica de "reglas vs código" (Firestore)
Compara `firestore.rules` con las colecciones usadas en el código:
- **`match_lineups`** (usada por el tab Formación en `lineup_screen.dart`) **NO está permitida** en `firestore.rules` → las escrituras de formación podrían ser **rechazadas en producción** (fallan en consola con `permission-denied`). Prueba guardar una formación con sesión DT y revisa el resultado.
- **Colecciones permitidas pero sin uso**: `players` y `payments` están en las reglas pero no se usan → no son funcionalidad muerta de UI, pero sí candidatas a limpieza.

### 4.6 Técnica de "permisos que no se cumplen" (seguridad funcional)
- **`EditChildProfileScreen` / `ChildDetailScreen`**: no hay gate de rol. Prueba si un tutor puede abrir la ficha de un hijo que NO es suyo (si llegara a un `childId` ajeno). 
- **Socio en Buzón**: el socio ve la vista "staff" (puede iniciar chats con cualquiera) porque `isNormalUser` no incluye a `socio`. Decide si es aceptable.
- **Secretario vs Directivo**: el bloqueo/eliminación del directivo se protege por email hardcodeado (`munozalbelonicolas@gmail.com`), no por rol. Prueba si un secretario puede bloquear a otro directivo (no el raíz).
- **`status` "inactive" / "pending_email"**: documentados en el modelo pero sin pantalla de manejo. Prueba qué pasa si un usuario tiene esos estados (debería quedar sin pantalla válida o caer en AppShell).

### 4.7 Técnica de "providers/funciones sin consumidor"
Código que existe pero nadie usa (detectable con grep en el IDE):
- `userPaymentsStreamProvider`, `attendanceStreamProvider`, `convocatoriaStreamProvider`, `lineupStreamProvider`, `coachReportsStreamProvider`, `announcementsStreamProvider`.
- `getCoachReports` / `deleteCoachReport` / `getPayments`.
- `NotificationService.showLocalNotification`, `OneSignalService.setRoleTag/setCategoryTag`, `CategoryService.ensureCategoryExists`.
- `PlayerProfileScreen` (sin import).
- `cloud functions` de notificaciones FCM (deshabilitadas por plan Spark) — el push real va por OneSignal.

---

## 5. Auditoría rápida de funcionalidad muerta — checklist de 20 puntos

Corre este checklist una vez por release:

- [ ] **1. PlayerProfileScreen**: ¿es accesible desde algún menú? (esperado: NO → código muerto)
- [ ] **2. Informes de DT**: ¿la directiva puede ver un informe enviado? (esperado: NO → sin lector)
- [ ] **3. Panel DT stats**: ¿los números cambian con datos reales? (esperado: NO → mock)
- [ ] **4. Panel DT "Convocatoria"/"Notas"**: ¿responden al toque? (esperado: NO → botones vacíos)
- [ ] **5. Home "Payment Status"/"Quick Stats"**: ¿aparecen alguna vez? (esperado: NO → UI muerta)
- [ ] **6. Informe de Liga adjunto**: ¿se puede descargar/abrir el archivo? (esperado: NO → subida mock)
- [ ] **7. Toggles de notificación (Settings)**: ¿persisten tras reabrir? (esperado: NO → decorativo)
- [ ] **8. Formación → guardar** (sesión DT): ¿se guarda en `match_lineups` sin error de permisos? (esperado: posible `permission-denied` por reglas)
- [ ] **9. "Mis Hijos" en Settings para DT/admin/socio**: ¿tiene sentido ver la sección? (anomalía de UI)
- [ ] **10. Socio en Buzón**: ¿puede iniciar chats con cualquiera? (quirk de permisos)
- [ ] **11. Editar hijo ajeno**: ¿un tutor puede editar la ficha de un hijo no vinculado? (seguridad)
- [ ] **12. Resultado esperado al aprobar un pedido de cuota**: ¿la cuota queda marcada como pagada en el jugador?
- [ ] **13. Cloud function `onUserDeleted`**: al eliminar un usuario, ¿también se borra de Firebase Auth?
- [ ] **14. `exportPostImage`**: al compartir una novedad como historia, ¿se genera la imagen correctamente?
- [ ] **15. Push OneSignal**: ¿llegan notificaciones por rol/categoría tras login?
- [ ] **16. "Mantener sesión"**: desmarcado → al reabrir pide login; marcado → mantiene sesión.
- [ ] **17. Usuario `disabled`**: al loguear muestra pantalla de bloqueo.
- [ ] **18. Tienda cerrada**: usuario normal ve aviso; admin ve la tienda.
- [ ] **19. Estado `inactive` / `pending_email`**: ¿qué pantalla muestra la app? (no gestionado → posible pantalla en blanco)
- [ ] **20. Logs**: ¿hay errores en consola (Flutter/Logcat) al ejecutar las tareas D/T/P críticas? (crash = bug, no funcionalidad muerta, pero atender igual).

---

## 6. Inventario de hallazgos conocidos (de la auditoría de código)

> Hallazgos detectados al auditar el código. **Verifícalos manualmente** y márcalos como confirmados o descartados.

| # | Hallazgo | Evidencia | Tipo | Acción sugerida |
|---|---|---|---|---|
| 1 | `PlayerProfileScreen` inaccesible | Sin ninguna referencia/import | Código muerto | Eliminar o conectar |
| 2 | Informes de DT sin pantalla de lectura | `coach_reports` solo se escribe | Feature incompleta | Agregar vista para directiva |
| 3 | Home "Payment Status"/"Quick Stats" nunca renderizan | `pendingPayment`/`player` = `const null` | UI muerta | Conectar o eliminar |
| 4 | Panel DT: stats mock + botones vacíos | `:122-139`, `:307`, `:331` | Mock / botones muertos | Conectar a datos reales |
| 5 | Informe de Liga: adjunto simulado | URL `https://example.com/...` | Feature simulada | Implementar upload real |
| 6 | Toggles de notificación decorativos | `_SettingToggle` estado local | UI decorativa | Implementar o quitar |
| 7 | `match_lineups` no permitida en reglas | `firestore.rules` vs `lineup_screen.dart` | Riesgo prod | Actualizar reglas |
| 8 | Colecciones `players` y `payments` sin uso | reglas vs código | Datos muertos | Limpiar reglas |
| 9 | Providers huérfanos | `convocatoria/lineup/payments/attendance/coachReports/announcements` | Código muerto | Limpiar |
| 10 | `announcementsStreamProvider` sin consumir | repositorio vs screens | Código muerto | Limpiar |
| 11 | Mapeo muerto `_handleHomeNavigation` caso 4 ("Results tab") | `app_shell.dart:46-48` | Código muerto | Limpiar |
| 12 | "Mis Hijos" visible para todos los roles ≠ jugador | `settings_screen.dart:95` | Anomalía UX | Restringir a tutor |
| 13 | Socio entra a Buzón como "staff" | `inbox_screen.dart:138` | Quirk de permisos | Revisar intención |
| 14 | Estados `inactive`/`pending_email` sin manejo | `main.dart` navigator | Caso sin cubrir | Definir pantalla/estado |
| 15 | FCM server notifications deshabilitadas | `functions/src/notifications.ts` comentado | Feature desactivada | Decidir si se usa OneSignal |
| 16 | `storage.rules` sin consumidores | la app sube a Cloudinary | Infraestructura muerta | Limpiar o migrar |

---

## 7. Pasos para reportar un hallazgo

1. Usa `qa/BUG_TEMPLATE.md` para documentar: título, rol, pasos, esperado, obtenido, evidencia (captura/log), severidad y prioridad.
2. Clasifícalo:
   - **Bug funcional**: la feature existe y está conectada pero no funciona como se espera.
   - **Funcionalidad muerta**: existe código/UI pero no es alcanzable o no tiene efecto.
   - **Feature simulada**: parece real pero usa datos/URLs falsos.
   - **Riesgo de producción**: fallaría en Firebase por reglas/permisos (p. ej. `match_lineups`).
3. Adjunta la salida de consola (Logcat / Flutter console) y capturas del estado de Firestore.

---

## 8. Criterio de cierre

- Todos los puntos del checklist (sección 5) verificados y documentados.
- 0 bugs Críticos/Alto abiertos.
- Hallazgos de funcionalidad muerta confirmados: priorizados (eliminar vs conectar) y con ticket en el gestor de tareas.
- Actualizar `01_ROLES_Y_FUNCIONALIDADES.md` si el comportamiento real difiere del documentado.
