# 01 · Roles, Funcionalidades y Tareas por Rol — AppClub

> Documento de referencia basado en el código fuente (`lib/`). Generado por auditoría de código.
> Roles definidos en `lib/core/models/user_session.dart`. Cada rol tiene acceso a un shell de navegación distinto (`lib/app/app_shell.dart`) y a secciones de "Más" (Settings) condicionadas por rol (`lib/features/settings/presentation/screens/settings_screen.dart`).

---

## 1. Modelo de Roles

| Rol (`role`) | Navegación | Acceso admin | Acceso DT | Notas |
|---|---|---|---|---|
| `directivo` | Shell estándar (6 tabs) | ✅ Admin completo (puede gestionar a TODOS) | — | Rol asignado por email en `auth_service.dart`. No puede ser bloqueado/eliminado. |
| `secretario` | Shell estándar (6 tabs) | ✅ Admin (no puede gestionar a `directivo`) | — | Misma UI que directivo en casi todas las pantallas. |
| `dt` | Shell estándar (6 tabs) | ❌ | ✅ Panel DT + herramientas de entrenador | Solo su(s) categoría(s) asignada(s). |
| `tutor` | Shell estándar (6 tabs) | ❌ | ❌ | Vincula hijos menores, paga cuotas, ve actividad de sus hijos. |
| `jugador` | Shell estándar (6 tabs) | ❌ | ❌ | Solo su ficha, apto físico, asistencias, goles. No comenta en novedades. |
| `socio` | Shell reducido (4 tabs) | ❌ | ❌ | Solo Inicio/Socio, Carnet, Tienda y Más. No ve Calendario/Formación/Noticias. |

**Estados de cuenta** (`status`): `pending_email` (no verificado), `pending_children` (tutor debe registrar hijo), `pending_approval` (esperando aprobación), `active`, `disabled` (bloqueado), `inactive` (documentado, no gestionado en UI).

---

## 2. Funcionalidades de la App (mapa de features)

Cada feature de la app pertenece a un módulo de `lib/features/`. Este es el inventario completo:

| Módulo | Feature | Descripción |
|---|---|---|
| auth | Login | Email+contraseña, Google Sign-In, recuperar contraseña, "mantener sesión". |
| auth | Registro | Alta de cuenta `tutor` o `socio` (con DNI y términos). |
| auth | Verificar email / Completar perfil / Aprobación pendiente | Flujos intermedios del onboarding. |
| home | Feed de novedades | Muro con posts (fotos, likes, comentarios, "visto por", compartir como historia, eliminar). |
| home | Quick actions | Accesos rápidos: Asistencia, Informe de Liga, Cuotas, Noticias. |
| home | Sponsors | Carrusel de sponsors con link externo. |
| home | Notificaciones admin | Campana con solicitudes de co-tutor, órdenes de tienda, cumpleaños, usuarios pendientes. |
| calendar | Calendario | Mes con eventos, partidos, entrenamientos, cumpleaños y fixtures. Filtros por tipo. |
| lineup | Formación / Convocatoria | Convocados del próximo partido, titulares ⭐, cancha y persistencia de convocatoria. |
| communications | Comunicados / Noticias | Comunicados oficiales con tipo de evento, comentarios, export a historia 9:16. |
| inbox | Buzón / Chat | Chats 1:1, hilos, modo auditoría para staff, "Escribir a la Secretaría". |
| attendance | Asistencia | Planilla jugador×fecha (Presente/Ausente/Justificado/Tardanza) y horarios de entrenamiento. |
| attendance | Asistencia (vista jugador) | Historial de asistencia del propio jugador o de un hijo (solo lectura). |
| coach_panel | Panel DT | Dashboard del entrenador (stats, partidos, informes, plantel). |
| coach_panel | Formación táctica | Editor de formación sobre cancha (5v5/7v7/8v8/11v11). |
| coach_panel | Informe a Directiva | Envío de informes privados del DT. |
| payments | Cuotas | Pago de cuota cooperadora de los hijos (crea orden en tienda). |
| player | Mi perfil | Edición de datos personales / ficha médica del jugador / gestión de hijos. |
| player | Registrar hijo | Alta o vinculación de jugador por DNI, solicitud de co-tutoría. |
| player | Perfil del hijo | Stats, info, ficha médica, historial de goles/tarjetas/asistencia. |
| player | Consolidado | Roster consolidado por categoría con estado de cuota + export Excel. |
| results | Resultados / Fixture / Posiciones / Goleadores | Marcadores, tabla de posiciones y goleadores por categoría. |
| results | Cargar resultados | DT/admin cargan resultados por partido o jornada completa. |
| settings | Consola del Director | Búsqueda/aprobación/eliminación de usuarios, email de soporte, accesos a gestión. |
| settings | Perfil de usuario (admin) | Aprobar, bloquear, cambiar rol, asignar DT, eliminar, desvincular. |
| settings | Gestión de Categorías | CRUD de categorías. |
| settings | Gestión de Cuotas | Estado de cuotas por jugador (meses pagados). |
| settings | Gestión de Sponsors | CRUD de sponsors con presets. |
| settings | Gestión de Clubes | CRUD de clubes (rivales/locales). |
| settings | Sistema de Cumpleaños | Config de publicaciones automáticas + listado de cumpleaños del mes. |
| settings | Términos / Privacidad / Soporte | Pantallas legales y formulario de soporte (con email de contacto configurable). |
| settings | Toggles de notificación | Preferencias de notificación (decorativas). |
| settings | Eliminar cuenta | Baja de cuenta conforme a Google Play. |
| socio | Dashboard socio | Bienvenida + últimas 5 novedades + accesos a Tienda/Carnet. |
| socio | Carnet digital | Carnet con QR `appclub://socio/<id>` y estado activo/pendiente. |
| store | Tienda | Catálogo de productos con filtros por categoría, talles y stock. |
| store | Checkout | Confirmación de pedido con datos bancarios (CBU/alias) y comprobante. |
| store | Mis compras | Historial de pedidos del usuario con estados. |
| store | Admin pedidos | Gestión de pedidos (confirmar, rechazar, entregar) y cuotas. |
| store | Admin tienda | Config de tienda (abierta/cerrada, datos bancarios) y CRUD de productos. |
| support | Soporte | Formulario de consulta a `support_inquiries`. |

---

## 3. Tareas que puede hacer cada rol (detallado con referencias de código)

### 3.1 Directivo (`directivo`)

| # | Tarea | Dónde | Referencia |
|---|---|---|---|
| D1 | Ver/crear/comentar/eliminar novedades del feed, ver "visto por", compartir como historia | Home | `home_screen.dart` |
| D2 | Ver notificaciones admin (co-tutor, compras, cumpleaños, usuarios pendientes) y aprobar/rechazar | Home (campana) | `home_screen.dart:839–882`, `admin_notifications_dialog.dart` |
| D3 | Acceso a Asistencia (planilla editable) | Quick action Home | `home_screen.dart:943–948` |
| D4 | Acceso a Informe de Liga, Cuotas y Noticias | Quick actions Home | `home_screen.dart:966–1001` |
| D5 | Ver calendario de TODAS las categorías | Tab Calendario | `calendar_screen.dart:96,270` |
| D6 | Ver y gestionar convocatoria/alineaciones | Tab Formación | `lineup_screen.dart` |
| D7 | Crear comunicados (tipo evento), comentar, ver vistas, exportar historia, toggle comentarios, eliminar | Tab Noticias | `communications_screen.dart:464–726` |
| D8 | Ver tienda y acciones admin: Pedidos, Configurar Tienda, Crear/Editar producto | Tab Tienda | `store_screen.dart:94–111`, `product_detail_screen.dart:74` |
| D9 | Gestionar pedidos: confirmar (marca cuota pagada), rechazar (restaura stock), entregar | Tienda → Pedidos | `admin_order_detail_screen.dart` |
| D10 | Consola del Director: buscar, aprobar, eliminar usuarios; ver notificaciones | Más → Consola del Director | `director_console_screen.dart` |
| D11 | Configurar email de soporte | Consola del Director | `director_console_screen.dart:658–806` |
| D12 | Gestionar categorías (CRUD) | Consola → Gestionar Categorías | `manage_categories_screen.dart` |
| D13 | Estado de cuotas (marcar meses pagados) | Consola → Estado de Cuotas | `manage_quotas_screen.dart` |
| D14 | Ver consolidado de jugadores + marcar al día/atrasado + export Excel | Consola → Consolidado | `consolidated_roster_screen.dart:206–234` |
| D15 | Cumpleaños del mes | Consola → Cumpleaños del Mes | `birthdays_of_month_screen.dart` |
| D16 | Configurar Sistema de Cumpleaños (posts automáticos, avisos) | Más → Sistema de Cumpleaños | `birthday_config_screen.dart` |
| D17 | Gestionar Sponsors (CRUD, presets, seed de prueba) | Más → Gestión de Sponsors | `sponsors_management_screen.dart` |
| D18 | Gestionar Clubes (CRUD) | Más → Competiciones → Gestión de Clubes | `club_management_screen.dart` |
| D19 | Gestionar Goleadores (CRUD) | Más → Competiciones → Goleadores | `manage_scorers_screen.dart` |
| D20 | Perfil de usuario admin: aprobar, bloquear/desbloquear, cambiar rol, asignar DT, eliminar cuenta, desvincular | Consola → usuario | `admin_user_profile_screen.dart` |
| D21 | Gestionar resultados: cargar jornada, goleadores, tarjetas, resultados | Más → Resultados | `results_screen.dart` |
| D22 | CRUD de fechas del fixture | Más → Fixture | `fixture_screen.dart` |
| D23 | Crear/eliminar informes de liga | Más → Informe de Liga | `league_report_screen.dart` |
| D24 | Buzón en modo auditoría (ver hilos ajenos), iniciar chats, buscar/filtrar | Más → Buzón | `inbox_screen.dart:246–252` |
| D25 | Ver ficha de cualquier jugador (vía consola/hijos) | Settings → Mis Hijos | `settings_screen.dart:95` |
| D26 | Soporte, términos, privacidad, eliminar cuenta, tema, logout | Más → Settings | `settings_screen.dart` |

### 3.2 Secretario (`secretario`)

- **Funcionalidad idéntica al Directivo** en la práctica (ambos `isAdmin`). Todas las tareas D1–D26 aplican.
- Única diferencia en código: `canManage` no puede gestionar a un `directivo` (`user_session.dart:191–192`), por lo que **no** puede bloquear/eliminar al directivo.

### 3.3 Entrenador / DT (`dt`)

| # | Tarea | Dónde | Referencia |
|---|---|---|---|
| T1 | Panel DT: ver plantel, stats (mock), próximos partidos | Más → Herramientas de DT → Panel DT | `coach_dashboard_screen.dart` |
| T2 | Control de Asistencia (planilla editable de su categoría) | Panel DT / Quick action Home | `attendance_screen.dart` |
| T3 | Consolidado de jugadores (solo lectura, sin marcar cuotas) + export Excel | Panel DT | `consolidated_roster_screen.dart:96–160,254` |
| T4 | Formación táctica del partido | Panel DT → Formación | `formation_screen.dart` |
| T5 | Convocatoria del próximo partido (convocar/desconvocar, titular ⭐) | Tab Formación | `lineup_screen.dart:379–447,715` |
| T6 | Programar / editar / eliminar partido (novedad tipo partido) | Panel DT | `coach_dashboard_screen.dart:224–361` |
| T7 | Enviar informe a la Directiva | Panel DT | `create_coach_report_screen.dart` |
| T8 | Gestionar goleadores (CRUD) | Más → Competiciones → Goleadores | `manage_scorers_screen.dart` |
| T9 | Crear comunicados (visibilidad fija a su categoría, evento "Partido") | Tab Noticias | `communications_screen.dart:64–84` |
| T10 | Crear novedades del feed (tipo partido) | Home | `home_screen.dart:157–163` |
| T11 | Cargar resultados, goleadores y tarjetas de partidos | Más → Resultados | `results_screen.dart:69–86` |
| T12 | Buzón: iniciar chats, escribir a usuarios de su categoría + directiva, filtros | Más → Buzón | `inbox_screen.dart:148–158,373–379` |
| T13 | Ver calendario de sus categorías | Tab Calendario | `calendar_screen.dart:100–106` |
| T14 | Editar horarios de entrenamiento de su categoría | Asistencia | `attendance_screen.dart:561–565` |
| T15 | Ver informes de liga / fixture de sus categorías | Más → Deportivo | `settings_screen.dart:249–290` |
| T16 | Soporte, términos, privacidad, eliminar cuenta, logout | Más → Settings | `settings_screen.dart` |

### 3.4 Tutor / Padre / Madre (`tutor`)

| # | Tarea | Dónde | Referencia |
|---|---|---|---|
| P1 | Seleccionar hijo en el Home (dropdown) | Home | `home_screen.dart:694–765` |
| P2 | Ver feed de novedades, comentar, dar like, compartir como historia, eliminar sus posts propios | Home | `home_screen.dart:1228–1295` |
| P3 | Ver asistencia de sus hijos | Quick action Asistencia | `player_attendance_screen.dart:151–231` |
| P4 | Acceder a Informe de Liga, Cuotas y Noticias | Quick actions Home | `home_screen.dart:966–1001` |
| P5 | Pagar cuota cooperadora de sus hijos (seleccionar mes → orden → comprobante) | Quick action Cuotas | `payments_screen.dart` |
| P6 | Ver calendario de las categorías de sus hijos | Tab Calendario | `calendar_screen.dart:111–122` |
| P7 | Ver convocatoria/formación (solo lectura) | Tab Formación | `lineup_screen.dart` |
| P8 | Ver resultados/fixture/goleadores de las categorías de sus hijos | Más → Resultados/Fixture | `results_screen.dart:45–56` |
| P9 | Editar su perfil (datos personales, teléfonos, avatar) | Más → Mi Perfil | `my_profile_screen.dart:503–541` |
| P10 | Registrar un hijo (DNI) o solicitar co-tutoría | Mi Perfil / flujo forzado | `register_player_screen.dart` |
| P11 | Ver/editar perfil de sus hijos (ficha médica, apto físico) | Más → Mis Hijos | `child_detail_screen.dart`, `edit_child_profile_screen.dart` |
| P12 | Buzón: escribir a la Secretaría | Más → Buzón | `inbox_screen.dart:432–478` |
| P13 | Ver informes de liga | Más → Deportivo | `league_report_screen.dart` |
| P14 | Comprar en la tienda (producto, checkout, subir comprobante, ver mis compras) | Tab Tienda | `store_screen.dart`, `checkout_screen.dart`, `order_detail_screen.dart` |
| P15 | Soporte, términos, privacidad, eliminar cuenta, tema, logout | Más → Settings | `settings_screen.dart` |

### 3.5 Jugador (`jugador`)

| # | Tarea | Dónde | Referencia |
|---|---|---|---|
| J1 | Ver feed de novedades, dar like, compartir (NO comentar, NO crear) | Home | `home_screen.dart:1142,1732,1991` |
| J2 | Ver su asistencia (solo lectura) | Quick action Asistencia | `player_attendance_screen.dart:234–253` |
| J3 | Ver calendario de SU categoría | Tab Calendario | `calendar_screen.dart:107–110` |
| J4 | Ver convocatoria/formación (solo lectura) | Tab Formación | `lineup_screen.dart` |
| J5 | Ver resultados/fixture de su categoría (sin gestión) | Más → Resultados | `results_screen.dart:69` |
| J6 | Editar su ficha: fecha nacimiento, peso, altura, nombres de tutores, avatar | Más → Mi Perfil | `my_profile_screen.dart:541–599,745–771` |
| J7 | Subir / renovar apto físico (con avisos de vencimiento) | Mi Perfil | `my_profile_screen.dart:775–835` |
| J8 | Ver "Mis Goles en el Torneo" | Mi Perfil | `my_profile_screen.dart:847–984` |
| J9 | Comprar en la tienda | Tab Tienda | `store_screen.dart` |
| J10 | Soporte, términos, privacidad, eliminar cuenta, tema, logout | Más → Settings | `settings_screen.dart` |

### 3.6 Socio (`socio`)

| # | Tarea | Dónde | Referencia |
|---|---|---|---|
| S1 | Dashboard socio: bienvenida, últimas 5 novedades | Tab Inicio (shell socio) | `socio_dashboard_screen.dart` |
| S2 | Ver carnet digital con QR y estado | Tab Carnet | `socio_carnet_screen.dart` |
| S3 | Comprar en la tienda | Tab Tienda | `store_screen.dart` |
| S4 | Editar su perfil | Más → Mi Perfil (Socio) | `my_profile_screen.dart:260` |
| S5 | Soporte, términos, privacidad, eliminar cuenta, logout | Más → Settings | `settings_screen.dart` |
| S6 | Registro como socio (DNI) con aprobación previa de la directiva | Registro público | `register_screen.dart:170,221` |

> ⚠️ **Nota de permisos socio:** en código `socio` entra al Buzón en vista "staff" (`inbox_screen.dart:138`) porque `isNormalUser` solo cubre `tutor`/`jugador`. Verificar si es intencional (ver Guía, sección 6).

---

## 4. Matriz resumen de acceso por rol

| Feature | directivo | secretario | dt | tutor | jugador | socio |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Feed de novedades (ver/like/compartir) | ✅ | ✅ | ✅ | ✅ | ✅ (sin comentar) | ✅ (5 en dashboard) |
| Crear novedades | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Comentar novedades | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Calendario | ✅ (todas) | ✅ (todas) | ✅ (sus cat.) | ✅ (hijos) | ✅ (su cat.) | ❌ |
| Convocatoria/Formación | ✅ (gestiona) | ✅ (gestiona) | ✅ (gestiona) | 👁️ lectura | 👁️ lectura | ❌ |
| Comunicados (crear) | ✅ | ✅ | ✅ (su cat.) | ❌ | ❌ | ❌ |
| Buzón | ✅ auditor | ✅ auditor | ✅ staff | ✅ usuario | ✅ usuario | ⚠️ staff (quirk) |
| Asistencia (editar) | ✅ | ✅ | ✅ (su cat.) | ❌ | ❌ | ❌ |
| Asistencia (ver) | ✅ | ✅ | ✅ | ✅ (hijos) | ✅ (propia) | ❌ |
| Cuotas (pagar) | — | — | — | ✅ (hijos) | ⚠️ sin vínculo | ❌ |
| Cuotas (gestionar) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Resultados (ver) | ✅ | ✅ | ✅ | ✅ (hijos) | ✅ (su cat.) | ❌ |
| Resultados (cargar) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Goleadores (gestionar) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Fixture (editar) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Informes de Liga (crear) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Informe a Directiva (DT) | 👁️ (debería leer; sin pantalla) | 👁️ | ✅ | ❌ | ❌ | ❌ |
| Consolidado jugadores | ✅ (marca cuota) | ✅ | 👁️ solo lectura | ❌ | ❌ | ❌ |
| Consola del Director | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gestionar Categorías | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gestionar Sponsors | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gestionar Clubes | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Sistema de Cumpleaños | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Registro de hijos | — | — | — | ✅ | ❌ | — |
| Carnet / Dashboard socio | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Tienda (comprar) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tienda (admin) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Soporte / Legales / Eliminar cuenta | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 5. Funcionalidades "transversales" (todos los roles)

- Login / Registro / Verificación de email / Completar perfil.
- Home con sponsors y noticias.
- Calendario, Formación (lectura), Noticias (lectura), Tienda (compra), Más (perfil, soporte, legales, tema oscuro, logout).
- Notificaciones push (OneSignal) y notificaciones in-app.

---

## 6. Hallazgos relevantes (para testing)

Estos puntos deben verificarse manualmente porque el código muestra anomalías (ver detalle en la Guía de Funcionalidad Muerta):

1. **`PlayerProfileScreen` es código muerto**: no hay ninguna ruta de navegación que lo abra (su funcionalidad está cubierta por `ChildDetailScreen` / `MyProfileScreen`).
2. **Informes del DT a Directiva no tienen pantalla de lectura**: la directiva no puede ver los informes que el DT envía (`coach_reports` solo se escribe).
3. **Tarjetas "Payment Status" y "Player Quick Stats" del Home no se renderizan** (variables hardcodeadas a `null`).
4. **Stats del Panel DT son mock** ("Puntos 13 / Posición 1° / Partidos 5") y botones "Convocatoria" / "Notas" están vacíos.
5. **Subida de archivo en Informe de Liga es simulada** (URL `https://example.com/...`).
6. **Toggles de notificación en Settings son decorativos** (no persisten ni tienen efecto).
7. **`match_lineups` no está permitida en `firestore.rules`** → escribir la formación desde el tab Formación podría fallar en producción.
8. La colección `players` y `payments` están permitidas en reglas pero no se usan.
