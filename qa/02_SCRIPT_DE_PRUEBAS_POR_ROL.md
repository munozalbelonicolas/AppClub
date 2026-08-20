# 02 · Script de Pruebas por Tarea (Testing Manual)

> Script de pruebas funcionales manuales, una por cada tarea definida en `01_ROLES_Y_FUNCIONALIDADES.md`.
> Cada caso tiene un ID con prefijo del rol: **D**=directivo, **SC**=secretario, **T**=DT, **P**=tutor, **J**=jugador, **S**=socio, **A**=general.
>
> Convenciones:
> - **Estado**: `PASÓ` / `FALLÓ` / `BLOQUEADO`.
> - **Severidad**: `Baja` / `Media` / `Alta` / `Crítica`.
> - Usa cuentas de prueba por rol (ver `TEST_DATA.md`). Verifica en Firebase Console cuando el paso diga "verificar en consola".
> - Al terminar cada caso, registra evidencia (captura) y resultado.

---

## 0. Preparación (todos los casos)

1. Tener la app corriendo (`flutter run` o build instalado).
2. Tener cuentas de prueba: `directivo`, `secretario`, `dt`, `tutor`, `jugador`, `socio`.
3. Tener un jugador/hijo vinculado a la cuenta tutor y una categoría asignada al DT.
4. Tener datos semilla en Firestore: sponsors, clubes, categorías, un partido próximo, un fixture, productos en tienda, config de tienda (CBU/alias), novedades y un comunicado.
5. Abrir la app con sesión del rol correspondiente.

---

## 1. Scripts del rol DIRECTIVO

### TC-D1 · Ver/crear/comentar/eliminar novedades y compartir historia
| Campo | Valor |
|---|---|
| **Precondiciones** | Sesión directivo. |
| **Pasos** | 1) Abrir Home. 2) Tap FAB + (crear novedad). 3) Ingresar título + texto + imagen. 4) Publicar. 5) Verificar que aparece en el feed. 6) Comentar una novedad ajena. 7) Tap ⋮ de un post propio → "Ver vistas" → "Compartir historia". 8) Tap ⋮ → Eliminar. |
| **Esperado** | La novedad aparece en el feed; comentario visible; "visto por" lista usuarios que la abrieron; el export genera la imagen de historia y abre el share sheet; al eliminar desaparece del feed y de consola. |
| **Estado / Severidad** | ___ / Alta |

### TC-D2 · Notificaciones admin (aprobar co-tutor)
| Campo | Valor |
|---|---|
| **Precondiciones** | Un tutor envió solicitud de co-tutoría; una compra de tienda pendiente. |
| **Pasos** | 1) Tap campana (🔔) en Home. 2) Ver la solicitud de co-tutor. 3) Aprobar. 4) Verificar en Firebase Console que `player_tutor_links` cambió de estado. 5) Rechazar otra solicitud y verificar. 6) Abrir una orden de tienda desde la notificación. |
| **Esperado** | El diálogo lista las solicitudes; aprobar crea/actualiza el vínculo; rechazar elimina/deniega; la orden abre `AdminOrderDetailScreen`. |
| **Estado / Severidad** | ___ / Alta |

### TC-D3 · Asistencia (planilla editable)
| Campo | Valor |
|---|---|
| **Precondiciones** | Categoría con jugadores y fechas de entrenamiento. |
| **Pasos** | 1) Quick action Asistencia. 2) Seleccionar categoría. 3) Tap en una celda para alternar estado (Presente→Ausente→Justificado→Tardanza). 4) Long-press para modal P/A/J/T. 5) Botón "Agregar Fecha". 6) Botón "Todos Presentes". |
| **Esperado** | Los estados se guardan en `attendance` (verificar en consola); la planilla refleja cambios; se agregan fechas. |
| **Estado / Severidad** | ___ / Alta |

### TC-D4 · Quick actions del Home
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tap "Informe Liga" → abre `LeagueReportScreen`. 2) Volver. 3) Tap "Cuotas" → abre `PaymentsScreen`. 4) Tap "Noticias" → tab Noticias. |
| **Esperado** | Cada quick action navega a la pantalla correcta. |
| **Estado / Severidad** | ___ / Media |

### TC-D5 · Calendario (todas las categorías)
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Calendario. 2) Navegar entre meses. 3) Aplicar filtros (Partidos/Entrenamientos/Eventos/Cumpleaños). 4) Tap en un día con evento. |
| **Esperado** | Se ven eventos de todas las categorías; los filtros funcionan; el detalle del día muestra los eventos. |
| **Estado / Severidad** | ___ / Media |

### TC-D6 · Formación y Convocatoria
| Campo | Valor |
|---|---|
| **Precondiciones** | Partido próximo con fecha cargada. |
| **Pasos** | 1) Tab Formación. 2) Seleccionar categoría. 3) Convocar/desconvocar jugadores. 4) Marcar titulares ⭐. 5) "Convocar Todos" / "Desconvocar Todos". |
| **Esperado** | La convocatoria persiste en `matches/<id>/convocatoria` (verificar en consola); la lista se actualiza. |
| **Estado / Severidad** | ___ / Alta |

### TC-D7 · Comunicados (crear, comentar, vistas, exportar, eliminar)
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Noticias. 2) FAB + → crear comunicado (elegir tipo de evento: partido/evento/jornada/etc.). 3) Publicar y verificar. 4) Comentar. 5) Menú ⋮ → Exportar historia. 6) Menú ⋮ → Ver vistas. 7) Menú ⋮ → Eliminar. |
| **Esperado** | El comunicado se guarda en `announcements`; el comentario se agrega; el export abre share; "visto por" lista usuarios; eliminar lo quita. |
| **Estado / Severidad** | ___ / Alta |

### TC-D8 · Tienda admin (pedidos, config, productos)
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Tienda. 2) Tap "Mis Compras" (opcional). 3) Tap "Pedidos" → AdminOrders. 4) Tap "Configurar" → StoreConfig (toggle abrir/cerrar + CBU/alias/banco/titular). 5) Tap FAB + → Crear Producto. 6) Ver un producto → Editar / Eliminar. |
| **Esperado** | Pedidos lista los pedidos por estado; config persiste en `settings/store_config`; producto se crea/edita/oculta (`isActive=false`). |
| **Estado / Severidad** | ___ / Alta |

### TC-D9 · Gestionar pedido (confirmar/rechazar/entregar)
| Campo | Valor |
|---|---|
| **Precondiciones** | Pedido en estado pendiente con comprobante. |
| **Pasos** | 1) Tienda → Pedidos → Pedido. 2) Tap Confirmar. 3) Verificar que el jugador pasa a "cuota pagada" (si era cuota) y stock decrementado. 4) Rechazar otro pedido y verificar que el stock se restaura. 5) Marcar Entregado. |
| **Esperado** | El estado de la orden cambia; se actualiza `users.quotaStatus`/`paidQuotas` y el stock de `store_products`; se notifica al comprador. |
| **Estado / Severidad** | ___ / Crítica |

### TC-D10 · Consola del Director (usuarios)
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Consola del Director. 2) Buscar usuario por nombre/email. 3) Aprobar un usuario `pending_approval`. 4) Eliminar un usuario de prueba. 5) Verificar en consola que `users/<id>` se eliminó y (cloud function `onUserDeleted`) que también se borró de Firebase Auth. |
| **Esperado** | La búsqueda filtra; aprobar cambia `status` a `active`; eliminar borra el doc y dispara la cloud function. |
| **Estado / Severidad** | ___ / Crítica |

### TC-D11 · Configurar email de soporte
| Campo | Valor |
|---|---|
| **Pasos** | 1) Consola del Director → Configuración de soporte. 2) Ingresar email. 3) Guardar. 4) Verificar en `config/support_settings`. 5) Como tutor, abrir Soporte y comprobar que muestra el email. |
| **Esperado** | El email se persiste y aparece en el formulario de soporte. |
| **Estado / Severidad** | ___ / Media |

### TC-D12 · Gestionar categorías
| Campo | Valor |
|---|---|
| **Pasos** | 1) Consola → Gestionar Categorías. 2) Crear categoría. 3) Verificar en `categories`. 4) Eliminar una categoría de prueba. |
| **Esperado** | CRUD funciona; la categoría nueva aparece en los selectores de la app. |
| **Estado / Severidad** | ___ / Media |

### TC-D13 · Estado de cuotas
| Campo | Valor |
|---|---|
| **Pasos** | 1) Consola → Estado de Cuotas. 2) Filtrar por categoría/estado. 3) Tap jugador → marcar meses pagados. 4) Guardar y verificar en `users.paidQuotas`. |
| **Esperado** | Los meses pagados se persisten y el estado del jugador se actualiza. |
| **Estado / Severidad** | ___ / Alta |

### TC-D14 · Consolidado de jugadores
| Campo | Valor |
|---|---|
| **Pasos** | 1) Consola → Consolidado (o Panel). 2) Seleccionar categoría. 3) Toggle estado de cuota Al día/Atrasado. 4) Exportar a Excel y abrir el archivo. |
| **Esperado** | Lista correcta; toggle persiste; el .xlsx se comparte/descarga y contiene los datos. |
| **Estado / Severidad** | ___ / Alta |

### TC-D15 · Cumpleaños del mes
| Campo | Valor |
|---|---|
| **Pasos** | 1) Consola → Cumpleaños del Mes. 2) Seleccionar un mes. |
| **Esperado** | Lista los jugadores activos con cumpleaños en ese mes. |
| **Estado / Severidad** | ___ / Baja |

### TC-D16 · Sistema de Cumpleaños (config)
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Sistema de Cumpleaños. 2) Activar publicaciones automáticas. 3) Ajustar días previos de aviso y plantilla con `{nombre}`. 4) Guardar. 5) (Opcional) Validar que al día siguiente se creó la novedad de cumpleaños. |
| **Esperado** | Config persistida en `settings/birthday_system`; el servicio de cumpleaños genera posts. |
| **Estado / Severidad** | ___ / Media |

### TC-D17 · Gestión de Sponsors
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Gestión de Sponsors. 2) Añadir sponsor (imagen, nombre, link). 3) Cargar presets. 4) "Cargar Sponsors de Prueba". 5) Eliminar uno. 6) Verificar el carrusel en Home. |
| **Esperado** | CRUD en `sponsors`; el carrusel del Home muestra los sponsors y el link abre el navegador. |
| **Estado / Severidad** | ___ / Media |

### TC-D18 · Gestión de Clubes
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Competiciones → Gestión de Clubes. 2) Crear club (nombre, logo, flag local). 3) Editar. 4) Eliminar. 5) Verificar en fixtures/resultados que el club aparece. |
| **Esperado** | CRUD en `clubs`; el club aparece en fixture y posiciones. |
| **Estado / Severidad** | ___ / Alta |

### TC-D19 · Gestión de Goleadores
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Competiciones → Goleadores (o Resultados). 2) Crear goleador (jugador + goles). 3) Editar. 4) Eliminar. 5) Ver tabla de goleadores en Resultados. |
| **Esperado** | CRUD en `scorers`; la tabla de goleadores se actualiza. |
| **Estado / Severidad** | ___ / Alta |

### TC-D20 · Perfil de usuario admin
| Campo | Valor |
|---|---|
| **Pasos** | 1) Consola → tap usuario. 2) Aprobar / Bloquear / Desbloquear. 3) Cambiar rol. 4) Asignar profe/DT a un jugador. 5) Eliminar cuenta (usuario de prueba). 6) Desvincular tutor/jugador. |
| **Esperado** | Cada acción persiste en `users`/`player_tutor_links`; un usuario bloqueado no puede iniciar sesión (verifica con esa cuenta); el directivo raíz (`munozalbelonicolas@gmail.com`) no puede ser bloqueado/eliminado. |
| **Estado / Severidad** | ___ / Crítica |

### TC-D21 · Resultados (cargar jornada, goleadores, tarjetas, resultados)
| Campo | Valor |
|---|---|
| **Precondiciones** | Fixture con fechas cargadas. |
| **Pasos** | 1) Más → Resultados. 2) Seleccionar categoría. 3) Tap "Cargar Jornada" → ingresar marcadores. 4) Tap "Goleadores" de un partido → agregar. 5) Tap "Tarjetas". 6) Tap "Resultado". 7) Ver tabla de posiciones actualizada. |
| **Esperado** | Marcadores guardados en `fixtures`; goleadores en `scorers`; la tabla de posiciones se recalcula (2/1/0). |
| **Estado / Severidad** | ___ / Alta |

### TC-D22 · CRUD de fechas del fixture
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Fixture. 2) Tap + → crear fecha con partidos por categoría. 3) Editar fecha. 4) Eliminar fecha. |
| **Esperado** | Fechas persisten en `fixtures`; aparecen en Resultados y Calendario. |
| **Estado / Severidad** | ___ / Alta |

### TC-D23 · Informes de Liga
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Informe de Liga. 2) Tap + → crear informe con archivo adjunto. 3) Verificar en `league_reports` (⚠️ la URL del adjunto es mock `https://example.com/...`). 4) Descargar adjunto. 5) Eliminar. |
| **Esperado** | El informe se crea/elimina; el listado lo muestra. **ADVERTENCIA:** el "adjuntar archivo" no sube realmente el archivo — verificar si esto es aceptable o es funcionalidad muerta. |
| **Estado / Severidad** | ___ / Media |

### TC-D24 · Buzón auditoría
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Buzón. 2) Ver hilos de otros usuarios (modo auditoría). 3) Buscar y filtrar. 4) Abrir un chat ajeno → debe mostrar banner "Modo Supervisión" y ser solo lectura. 5) FAB → iniciar nuevo chat. |
| **Esperado** | El modo auditoría muestra todos los hilos; el chat en supervisión no permite enviar mensajes; el FAB crea un hilo nuevo. |
| **Estado / Severidad** | ___ / Alta |

### TC-D25 · Ver ficha de jugador
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Mis Hijos (o Consola → usuario). 2) Abrir ficha. 3) Navegar tabs Estadísticas/Info/Médica. 4) Tap Asistencia. 5) Tap Editar. |
| **Esperado** | Se muestra stats, historial de goles/tarjetas, ficha médica y acceso a edición/asistencia. |
| **Estado / Severidad** | ___ / Media |

---

## 2. Scripts del rol SECRETARIO

> El secretario comparte **todas** las tareas D1–D26 del directivo. Pruebas adicionales:

### TC-SC1 · No puede gestionar al directivo
| Campo | Valor |
|---|---|
| **Pasos** | 1) Sesión secretario. 2) Consola → buscar el usuario directivo. 3) Intentar bloquear/eliminar/cambiar rol. |
| **Esperado** | La acción debe estar bloqueada (o fallar silenciosamente). **Registrar el comportamiento real** (puede ser un bug: no hay gate explícito en todas las acciones). |
| **Estado / Severidad** | ___ / Media |

### TC-SC2 · Puede aprobar usuarios y gestionar todo lo administrativo
| Campo | Valor |
|---|---|
| **Pasos** | 1) Ejecutar TC-D10, TC-D20, TC-D13, TC-D9 con sesión secretario. |
| **Esperado** | Mismas capacidades que directivo excepto sobre el rol directivo. |
| **Estado / Severidad** | ___ / Alta |

---

## 3. Scripts del rol DT (Entrenador)

### TC-T1 · Panel DT
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Herramientas de DT → Panel DT. 2) Ver stats del plantel. |
| **Esperado** | El panel abre y muestra plantel y próximos partidos. ⚠️ **Hallazgo:** los valores "Puntos 13 / Posición 1° / Partidos 5" están **hardcodeados** (mock). Registrar si se muestran datos reales o falsos. |
| **Estado / Severidad** | ___ / Media |

### TC-T2 · Control de asistencia
| Campo | Valor |
|---|---|
| **Pasos** | 1) Panel DT → Control de Asistencia (o Quick action). 2) Seleccionar categoría (debe limitar a las asignadas). 3) Marcar/alternar estados. 4) Editar horario de entrenamiento. |
| **Esperado** | Solo ve sus categorías; los estados y horarios se persisten en `attendance`/`training_schedules`. |
| **Estado / Severidad** | ___ / Alta |

### TC-T3 · Consolidado (solo lectura para DT)
| Campo | Valor |
|---|---|
| **Pasos** | 1) Panel DT → Consolidado. 2) Seleccionar categoría. 3) Intentar cambiar estado de cuota (debe estar deshabilitado). 4) Exportar Excel. |
| **Esperado** | No puede modificar el estado de cuota (solo admin); el export funciona. |
| **Estado / Severidad** | ___ / Media |

### TC-T4 · Formación táctica
| Campo | Valor |
|---|---|
| **Pasos** | 1) Panel DT → Formación. 2) Elegir formato (5v5/7v7/8v8/11v11 o "Solo lista") y táctica. 3) Asignar jugadores a slots. 4) Guardar. 5) Verificar en `matches/<id>/lineup`. |
| **Esperado** | La formación se guarda y carga al reabrir. |
| **Estado / Severidad** | ___ / Alta |

### TC-T5 · Convocatoria
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Formación. 2) Convocar/desconvocar. 3) Marcar titulares. 4) "Convocar Todos". 5) Verificar en `matches/<id>/convocatoria`. |
| **Esperado** | Persistencia correcta y lectura por tutores/jugadores. |
| **Estado / Severidad** | ___ / Alta |

### TC-T6 · Programar/editar/eliminar partido
| Campo | Valor |
|---|---|
| **Pasos** | 1) Panel DT → Programar partido (crea novedad tipo partido). 2) Verificar que aparece en Calendario y Feed. 3) Editar partido. 4) Eliminar partido. |
| **Esperado** | El partido se crea en `novedades` y aparece en calendario; editar/eliminar funciona. |
| **Estado / Severidad** | ___ / Alta |

### TC-T7 · Enviar informe a Directiva
| Campo | Valor |
|---|---|
| **Pasos** | 1) Panel DT → Enviar Informe. 2) Título + descripción + imagen. 3) Enviar. 4) Verificar en consola que se creó `coach_reports`. |
| **Esperado** | El informe se guarda. ⚠️ **Hallazgo:** la Directiva **no tiene pantalla para verlo** (funcionalidad de escritura sin lectura). Registrar si esto es un problema. |
| **Estado / Severidad** | ___ / Media |

### TC-T8 · Gestionar goleadores
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Competiciones → Goleadores. 2) Crear/editar/eliminar. 3) Verificar en Resultados. |
| **Esperado** | CRUD funciona. |
| **Estado / Severidad** | ___ / Media |

### TC-T9 · Crear comunicado (visibilidad a su categoría)
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Noticias → FAB +. 2) Verificar que la categoría está fijada a su categoría y el tipo de evento a "Partido". 3) Publicar. 4) Verificar visibilidad desde un tutor de esa categoría y de otra. |
| **Esperado** | El comunicado es visible solo para su categoría (regla de negocio). |
| **Estado / Severidad** | ___ / Media |

### TC-T11 · Cargar resultados
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Resultados. 2) Cargar goleadores/tarjetas/resultado de un partido de su categoría. |
| **Esperado** | Guarda correctamente. |
| **Estado / Severidad** | ___ / Alta |

### TC-T12 · Buzón restringido a su categoría + directiva
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Buzón. 2) Iniciar chat con un tutor de su categoría (debe permitir). 3) Iniciar chat con un tutor de OTRA categoría (debe bloquear). 4) Iniciar chat con secretario/directivo (debe permitir). |
| **Esperado** | Restricción de destinatarios por categoría y directiva. |
| **Estado / Severidad** | ___ / Alta |

---

## 4. Scripts del rol TUTOR

### TC-P1 · Selector de hijo en Home
| Campo | Valor |
|---|---|
| **Precondiciones** | Tutor con ≥2 hijos vinculados. |
| **Pasos** | 1) Abrir Home. 2) Cambiar de hijo en el dropdown. 3) Verificar que el feed/cuotas/asistencia se adaptan. |
| **Esperado** | Al cambiar el hijo, la información contextual cambia. |
| **Estado / Severidad** | ___ / Media |

### TC-P2 · Feed: comentar, like, compartir
| Campo | Valor |
|---|---|
| **Pasos** | 1) Comentar una novedad. 2) Dar like. 3) Compartir como historia (si aplica). 4) Crear post → debe estar deshabilitado para tutor. |
| **Esperado** | Comenta y like funcionan; el botón crear NO está disponible para tutor. |
| **Estado / Severidad** | ___ / Media |

### TC-P3 · Ver asistencia de los hijos
| Campo | Valor |
|---|---|
| **Pasos** | 1) Quick action Asistencia. 2) Cambiar de hijo en el selector. 3) Ver KPIs y listado. |
| **Esperado** | Muestra % asistencia, presentes/ausentes/justificados y detalle por fecha; sin opciones de edición. |
| **Estado / Severidad** | ___ / Alta |

### TC-P5 · Pagar cuota cooperadora
| Campo | Valor |
|---|---|
| **Precondiciones** | Hijo con deuda; tienda configurada. |
| **Pasos** | 1) Quick action Cuotas. 2) Seleccionar jugador. 3) Seleccionar mes. 4) "Pagar" → abre OrderDetail. 5) Subir comprobante. 6) Verificar orden en `store_orders` con `isQuotaPayment: true`. |
| **Esperado** | Se crea la orden de cuota; el comprobante se sube; al confirmar el admin, la cuota queda pagada. |
| **Estado / Severidad** | ___ / Crítica |

### TC-P6 · Calendario de las categorías de sus hijos
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Calendario. 2) Verificar que solo ve categorías de sus hijos. |
| **Esperado** | Solo eventos de las categorías de sus hijos. |
| **Estado / Severidad** | ___ / Media |

### TC-P9 · Editar perfil propio
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Mi Perfil. 2) Cambiar avatar, nombre, teléfonos. 3) Guardar. 4) Verificar en `users`. |
| **Esperado** | Los cambios persisten. |
| **Estado / Severidad** | ___ / Media |

### TC-P10 · Registrar hijo / solicitar co-tutoría
| Campo | Valor |
|---|---|
| **Precondiciones** | Cuenta tutor nueva sin hijos. |
| **Pasos** | 1) Al loguear, el flujo forzado "Registrar un hijo" debe aparecer. 2) Completar datos (DNI, nombre, nacimiento, peso, altura, foto). 3) Registrar. 4) Verificar que el tutor pasa a `pending_approval`. 5) Con un DNI existente → debe ofrecer "solicitar co-tutoría". |
| **Esperado** | Se crea/vincula jugador en `users` + `player_tutor_links`; al registrarse pasa a `pending_approval`; la co-tutoría crea una solicitud que el admin aprueba. |
| **Estado / Severidad** | ___ / Crítica |

### TC-P11 · Editar perfil del hijo
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Mis Hijos → hijo. 2) Editar perfil (avatar, datos, apto físico). 3) Guardar. 4) Verificar en `users`/`player_tutor_links`. |
| **Esperado** | Los cambios persisten. ⚠️ **Hallazgo de seguridad:** no hay gate de rol en `EditChildProfileScreen` — verificar si un usuario puede editar un hijo que no es suyo (test de permisos). |
| **Estado / Severidad** | ___ / Alta |

### TC-P12 · Escribir a la Secretaría
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Buzón. 2) Tap "Escribir a la Secretaría". 3) Enviar mensaje. 4) Verificar hilo en `inbox_threads` y que el staff lo vea. |
| **Esperado** | El hilo se crea con la Secretaría y el mensaje llega. |
| **Estado / Severidad** | ___ / Alta |

### TC-P14 · Comprar en tienda
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Tienda → producto. 2) Elegir talle y cantidad. 3) Comprar → checkout (ver CBU/alias). 4) Confirmar pedido. 5) Subir comprobante. 6) Ver "Mis Compras" con estado. |
| **Esperado** | Se crea orden en `store_orders`; el stock decrementa; el comprobante se sube; el estado se actualiza al confirmar el admin. |
| **Estado / Severidad** | ___ / Crítica |

---

## 5. Scripts del rol JUGADOR

### TC-J1 · Feed: like y compartir, sin comentar
| Campo | Valor |
|---|---|
| **Pasos** | 1) Dar like. 2) Intentar comentar → debe mostrar "Los jugadores no pueden realizar comentarios." 3) Intentar crear post → sin FAB. |
| **Esperado** | Like funciona; comentar bloqueado; sin opción de crear. |
| **Estado / Severidad** | ___ / Media |

### TC-J2 · Ver su asistencia
| Campo | Valor |
|---|---|
| **Pasos** | 1) Quick action Asistencia. 2) Ver KPIs y detalle de su propia asistencia. |
| **Esperado** | Solo su información; sin edición. |
| **Estado / Severidad** | ___ / Media |

### TC-J6 · Editar ficha
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Mi Perfil. 2) Editar peso, altura, fecha nacimiento, tutores. 3) Guardar. |
| **Esperado** | Cambios persisten; los teléfonos NO deben ser editables para jugador. |
| **Estado / Severidad** | ___ / Media |

### TC-J7 · Subir apto físico
| Campo | Valor |
|---|---|
| **Precondiciones** | Jugador sin apto físico o con apto vencido. |
| **Pasos** | 1) Mi Perfil → subir apto físico (foto). 2) Verificar avisos (vencido/por vencer ≤30 días). 3) Verificar URL en `users.aptoFisicoUrl` y fecha en `aptoFisicoExpiry`. |
| **Esperado** | El apto se sube (Cloudinary) y los avisos de vencimiento aparecen. |
| **Estado / Severidad** | ___ / Alta |

### TC-J8 · Mis goles en el torneo
| Campo | Valor |
|---|---|
| **Pasos** | 1) Mi Perfil → "Mis Goles en el Torneo". 2) Verificar que los goles coinciden con `scorers` (o el dato fuente). |
| **Esperado** | La sección lista sus goles por partido/torneo. |
| **Estado / Severidad** | ___ / Media |

---

## 6. Scripts del rol SOCIO

### TC-S1 · Dashboard socio
| Campo | Valor |
|---|---|
| **Precondiciones** | Sesión socio activo. |
| **Pasos** | 1) Verificar shell de 4 tabs (Inicio/Carnet/Tienda/Más). 2) Ver bienvenida, accesos a Tienda/Carnet y últimas 5 novedades. |
| **Esperado** | No aparecen los tabs Calendario/Formación/Noticias. |
| **Estado / Severidad** | ___ / Media |

### TC-S2 · Carnet digital
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Carnet. 2) Ver QR y estado (SOCIO ACTIVO si `status == active`). |
| **Esperado** | QR con `appclub://socio/<id>` y estado correcto. |
| **Estado / Severidad** | ___ / Media |

### TC-S3 · Comprar en tienda
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tab Tienda. 2) Comprar producto, checkout, subir comprobante, ver mis compras. |
| **Esperado** | Flujo completo de compra funciona. |
| **Estado / Severidad** | ___ / Alta |

### TC-S4 · Perfil socio
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Mi Perfil (Socio). 2) Editar datos. |
| **Esperado** | El label dice "Mi Perfil (Socio)" y los cambios persisten. |
| **Estado / Severidad** | ___ / Baja |

### TC-S6 · Registro socio con aprobación
| Campo | Valor |
|---|---|
| **Pasos** | 1) Registro → elegir rol Socio. 2) Completar con DNI obligatorio. 3) Crear cuenta. 4) Verificar que queda en `pending_approval`. 5) Que la directiva lo apruebe → accede al shell socio. |
| **Esperado** | DNI obligatorio; aprobación requerida. |
| **Estado / Severidad** | ___ / Alta |

---

## 7. Scripts generales (transversales a todos los roles)

### TC-A1 · Login email/password + "Mantener sesión"
| Campo | Valor |
|---|---|
| **Pasos** | 1) Login con credenciales válidas. 2) Cerrar app y reabrir (sesión persistida). 3) Login con credenciales inválidas → error. 4) Desmarcar "Mantener sesión" → al reabrir pide login. 5) "¿Olvidaste tu contraseña?" → llega email. |
| **Esperado** | Login ok/fallo correcto; sesión persiste según switch; email de recuperación enviado. |
| **Estado / Severidad** | ___ / Crítica |

### TC-A2 · Login con Google
| Campo | Valor |
|---|---|
| **Pasos** | 1) Tap "Continuar con Google". 2) Completar flujo. 3) Si faltan teléfonos/términos → CompleteProfileScreen. |
| **Esperado** | Sesión iniciada; flujo de registro incompleto según rol. |
| **Estado / Severidad** | ___ / Alta |

### TC-A3 · Verificación de email
| Campo | Valor |
|---|---|
| **Pasos** | 1) Registrar cuenta. 2) Verificar que no entra sin verificar email. 3) "Reenviar correo". 4) Verificar desde el email → "Ya lo verifiqué". |
| **Esperado** | Bloqueo hasta verificar; reenvío funciona. |
| **Estado / Severidad** | ___ / Alta |

### TC-A4 · Usuario bloqueado (disabled)
| Campo | Valor |
|---|---|
| **Precondiciones** | Admin bloquea una cuenta de prueba. |
| **Pasos** | 1) Intentar loguear con esa cuenta. |
| **Esperado** | Pantalla "Usuario Bloqueado" con botón Cerrar Sesión. |
| **Estado / Severidad** | ___ / Alta |

### TC-A5 · Tienda cerrada
| Campo | Valor |
|---|---|
| **Precondiciones** | Admin desactiva la tienda. |
| **Pasos** | 1) Como usuario normal abrir Tienda. 2) Como admin abrir Tienda. |
| **Esperado** | Usuario normal ve "tienda cerrada"; admin ve la tienda igual. |
| **Estado / Severidad** | ___ / Media |

### TC-A6 · Soporte
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Soporte. 2) Ver email de soporte configurado. 3) Enviar consulta. 4) Verificar en `support_inquiries`. |
| **Esperado** | La consulta se guarda y se muestra confirmación. |
| **Estado / Severidad** | ___ / Media |

### TC-A7 · Eliminar cuenta
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Eliminar cuenta. 2) Confirmar. 3) Verificar que el doc `users/<id>` se eliminó y la cloud function borró la cuenta de Auth. |
| **Esperado** | Cuenta eliminada de Firestore y Auth. |
| **Estado / Severidad** | ___ / Crítica |

### TC-A8 · Tema oscuro
| Campo | Valor |
|---|---|
| **Pasos** | 1) Más → Settings → toggle tema oscuro. |
| **Esperado** | La app cambia a tema oscuro/claro y persiste la preferencia. |
| **Estado / Severidad** | ___ / Baja |

### TC-A9 · Push notifications (OneSignal)
| Campo | Valor |
|---|---|
| **Pasos** | 1) Iniciar sesión → se registra el dispositivo. 2) Desde otra cuenta, enviar una notificación (comunicado, chat, pedido). 3) Verificar recepción push. |
| **Esperado** | La notificación push llega según tags de rol/categoría. |
| **Estado / Severidad** | ___ / Media |

---

## 8. Plantilla de registro de resultados

Para cada caso copia esta fila en la hoja de seguimiento:

```
| <TC-XXX> | <Fecha> | <Tester> | <Dispositivo/OS> | PASÓ/FALLÓ/BLOQUEADO | <Evidencia/captura> | <Comentario> |
```

Criterios de aceptación (DoD):
- 0 Bugs **Críticos** o **Altos** abiertos.
- 100% de los smoke tests aprobados.
