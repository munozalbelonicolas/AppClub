# 📖 Manual de Usuario y Guía de Funcionalidades por Rol
## Asociación Deportiva Infantil y Juvenil Jorge Newbery

---

## 📌 1. Introducción y Estructura General

La aplicación oficial del **Club Jorge Newbery** está diseñada con una arquitectura modular y adaptativa basada en **roles de usuario**. Cada tipo de cuenta dispone de una interfaz optimizada con accesos, permisos y herramientas específicas.

### Barra de Navegación Principal (Inferior)
- **Deportistas, DTs, Directivos y Tutores:**
  1. 🏠 **Inicio:** Resumen de partidos, convocatorias activas, accesos rápidos y feed de novedades.
  2. 📅 **Calendario:** Fixture de partidos, entrenamientos y eventos institucionales.
  3. ⚽ **Formación:** Pizarra táctica, alineaciones interactivas y armado de convocatorias.
  4. 📢 **Noticias / Comunicados:** Feed oficial del club con filtro por categoría y creador de historias.
  5. 🛍️ **Tienda:** Catálogo oficial de indumentaria y productos del club.
  6. ⚙️ **Más / Ajustes:** Perfil, herramientas administrativas, gestión de cuotas y soporte.

- **Socios del Club:**
  1. 🏠 **Inicio:** Dashboard social y estado del socio.
  2. 🪪 **Carnet:** Carnet digital de socio con código QR dinámico.
  3. 🛍️ **Tienda:** Tienda de indumentaria del club.
  4. ⚙️ **Más:** Configuración de perfil y notificaciones.

---

## 👥 2. Funcionalidades Detalladas por Rol

---

### 👔 ROL 1: Directivo / Secretario / Administrador
*Control total sobre la gestión deportiva, administrativa y comunicacional del club.*

| Módulo / Función | ¿Dónde se encuentra? | ¿Qué puede hacer? |
| :--- | :--- | :--- |
| **Consola de Dirección** | `Más (⚙️) > Consola de Dirección` | Panel de métricas globales: total de jugadores, socios, recaudación y estado de cuotas. |
| **Gestión de Planteles y Carnets** | `Más (⚙️) > Planteles Consolidados` | Ver y filtrar jugadores por categoría, editar perfiles y generar **Carnets Digitales Oficiales en PDF/PNG**. |
| **Control y Cobro de Cuotas** | `Más (⚙️) > Gestión de Cuotas` | Marcar meses pagados (Enero a Diciembre) de cada jugador, filtrar por estado de morosidad y categoría. |
| **Aprobación de Usuarios** | `Más (⚙️) > Aprobaciones Pendientes` | Aprobar o rechazar el registro de nuevos tutores, jugadores y solicitudes de vínculo familiar. |
| **Publicación de Novedades y Push** | `Inicio (🏠) [+]` ó `Noticias (📢) [+]` | Crear anuncios, noticias de partidos o salutaciones de cumpleaños. **Dispara notificaciones Push automáticas** a todo el club o por categoría. |
| **Exportar Historias para Redes** | `Noticias (📢) > Ver Noticia > Exportar Historia` | Genera placa gráfica 9:16 de alta resolución con escudo, tipografía y branding oficial para compartir en Instagram/WhatsApp. |
| **Gestión de la Tienda Oficial** | `Tienda (🛍️)` | Publicar nuevos productos, fijar precios, talles, stock y gestionar pedidos entrantes. |
| **Fixture y Calendario Oficial** | `Calendario (📅)` | Crear y editar partidos de cualquier categoría, definir rival, horario, localía y canchas. |
| **Mensajería / Chat Global** | `Inicio (🏠) > Ícono Mensajes (💬)` | Buscar cualquier usuario del club por nombre, rol o categoría e iniciar conversaciones directas. |

---

### 📋 ROL 2: Director Técnico (DT) / Profesor / Entrenador
*Herramientas especializadas para el día a día deportivo, entrenamientos y partidos.*

| Módulo / Función | ¿Dónde se encuentra? | ¿Qué puede hacer? |
| :--- | :--- | :--- |
| **Selector de Categorías Activas** | `Parte superior de Inicio y Asistencia` | Conmutar instantáneamente entre las categorías asignadas (ej. `2017`, `2019`). Toda la app se filtra a la categoría elegida. |
| **Planilla de Control de Asistencia** | `Inicio (🏠) > Control de Asistencia` | Planilla matricial interactiva. Al tocar cada celda cicla continuamente: **Presente (P)** ➔ **Ausente (A)** ➔ **Justificado (J)** ➔ **Tardanza (T)** ➔ **Presente (P)**. |
| **Marcar Todos Presentes** | `Asistencia > Botón "Marcar Todos Presentes"` | Marca a todo el plantel en verde con un solo toque para agilizar la toma de asistencia. |
| **Pizarra Táctica y Formación** | `Formación (⚽)` | Diseñar esquema táctico (4-3-3, 4-4-2, etc.), arrastrar jugadores a la cancha y guardar la formación del partido. |
| **Convocatorias a Partidos** | `Formación (⚽) > Convocatoria` | Seleccionar los jugadores citados para el próximo encuentro. Los tutores reciben la notificación para confirmar presencia. |
| **Carga de Resultados y Goleadores** | `Calendario (📅) > Ver Partido > Cargar Resultado` | Registrar goles a favor/en contra, minutos de juego, tarjetas y goleadores del equipo. |
| **Horarios de Entrenamiento** | `Asistencia > Tarjeta de Entrenamiento` | Configurar días (Lun, Mié, Vie), horarios de inicio/fin y cancha asignada. |
| **Comunicados de Categoría** | `Noticias (📢) [+]` | Enviar avisos urgentes a los padres de sus categorías asignadas con Push Notification. |
| **Mensajería con Familias** | `Inicio (🏠) > Mensajes (💬)` | Chat directo con los tutores y jugadores de sus categorías sin necesidad de compartir número de teléfono personal. |

---

### 👨‍👩‍👦 ROL 3: Tutor / Familiar
*Seguimiento del deportista a cargo, confirmación de partidos, pagos y contacto con el club.*

| Módulo / Función | ¿Dónde se encuentra? | ¿Qué puede hacer? |
| :--- | :--- | :--- |
| **Selector de Hijos / Deportistas** | `Encabezado de Inicio (🏠)` | Si tiene más de un hijo/a en el club, puede alternar entre ellos con el desplegable superior. |
| **Confirmación de Partidos** | `Inicio (🏠) > Tarjeta de Próximo Partido` | Botones directos para **"Confirmar Asistencia"** o indicar **"No puede ir"** al DT con un solo toque. |
| **Carnet Digital del Jugador** | `Inicio (🏠) > Carnet Digital` | Visualizar el carnet oficial con foto, DNI, categoría y código QR de validación. |
| **Estado de Cuotas** | `Inicio (🏠) > Tarjeta de Cuotas` ó `Más (⚙️)` | Comprobar qué meses están al día y cuáles tienen cuotas pendientes. |
| **Estadísticas y Asistencias del Hijo** | `Inicio (🏠) > Asistencia del Jugador` | Gráfico de asistencia mensual, asistencias a entrenamientos y partidos jugados. |
| **Editar Ficha Médica y Datos del Hijo** | `Más (⚙️) > Editar Perfil del Hijo` | Modificar grupo sanguíneo, obra social, alergias, observaciones médicas y contacto de emergencia. |
| **Vincular Nuevo Hijo** | `Más (⚙️) > Registrar / Vincular Jugador` | Solicitar la vinculación de un nuevo deportista al perfil del tutor. |
| **Noticias del Club y Categoría** | `Noticias (📢)` | Feed personalizado con comunicados institucionales y novedades de la categoría de sus hijos. |

---

### 🏃 ROL 4: Jugador (Deportista)
*Acceso personalizado para el atleta a su agenda, estadísticas e identidad en el club.*

| Módulo / Función | ¿Dónde se encuentra? | ¿Qué puede hacer? |
| :--- | :--- | :--- |
| **Mi Carnet Oficial** | `Inicio (🏠) > Mi Carnet` | Carnet digital de jugador válido para acreditaciones y eventos. |
| **Próximos Partidos y Entrenamientos** | `Inicio (🏠)` y `Calendario (📅)` | Ver fecha, rival, cancha, horario y si está convocado para el próximo partido. |
| **Historial de Asistencias** | `Inicio (🏠) > Mi Asistencia` | Ver el porcentaje de presentismo y registro de entrenamientos. |
| **Mi Perfil Deportivo** | `Más (⚙️) > Mi Perfil` | Modificar foto de perfil, posición en cancha, pie hábil y apodo. |
| **Tutores Asignados (Solo Lectura)** | `Más (⚙️) > Mi Perfil > Tutores Asignados` | Consulta quiénes son los tutores vinculados a su ficha, con teléfono y correo de contacto (sin poder alterarlos por seguridad). |
| **Novedades del Club** | `Noticias (📢)` | Leer anuncios oficiales, tablas de goleadores y felicitar a compañeros por cumpleaños. |

---

### 🎗️ ROL 5: Socio
*Experiencia pensada para socios activos y simpatizantes de la institución.*

| Módulo / Función | ¿Dónde se encuentra? | ¿Qué puede hacer? |
| :--- | :--- | :--- |
| **Carnet de Socio Digital** | `Pestaña Carnet (🪪)` | Carnet oficial de socio con número de socio, categoría y código QR de acceso a instalaciones. |
| **Dashboard del Socio** | `Pestaña Inicio (🏠)` | Novedades institucionales, estado de la membresía y convocatorias a asambleas. |
| **Tienda Oficial del Club** | `Pestaña Tienda (🛍️)` | Comprar indumentaria deportiva, camisetas y accesorios oficiales. |
| **Canal de Soporte / Consultas** | `Más (⚙️) > Centro de Ayuda` | Enviar consultas directas a la administración del club. |

---

## 🔍 3. Matriz Rápida: "¿Dónde encuentro cada cosa?"

| Si necesitas... | Ve a: | Accesible para: |
| :--- | :--- | :--- |
| **Ver la fecha y cancha del próximo partido** | `Inicio (🏠)` ó `Calendario (📅)` | Todos los roles |
| **Tomar asistencia en un entrenamiento** | `Inicio (🏠) > Control de Asistencia` | DTs, Directivos |
| **Avisar que mi hijo NO puede ir al partido** | `Inicio (🏠) > Tarjeta de Partido > "No puede ir"` | Tutores |
| **Buscar a un DT o directivo para hablarle** | `Inicio (🏠) > Ícono Chat (💬) > [+] Nuevo Chat` | Todos los roles |
| **Descargar el carnet digital** | `Inicio (🏠) > Carnet Digital` | Jugadores, Tutores, Socios |
| **Saber si tengo cuotas vencidas** | `Inicio (🏠) > Tarjeta de Cuotas` | Tutores, Socios |
| **Publicar una placa para Instagram** | `Noticias (📢) > Exportar para Historia` | DTs, Directivos |
| **Actualizar el grupo sanguíneo de un jugador** | `Más (⚙️) > Editar Perfil del Hijo` | Tutores, Directivos |
| **Ver la tabla de goleadores** | `Calendario (📅) > Goleadores` | Todos los roles |
| **Cambiar entre mis hijos registrados** | `Desplegable superior en Inicio (🏠)` | Tutores |
| **Cambiar entre mis categorías de entrenamiento** | `Desplegable superior en Inicio y Asistencia` | DTs |

---

## 🛡️ 4. Notificaciones, Tema y Sesión

1. **Notificaciones Push en Tiempo Real:** Las convocatorias a partidos y comunicados urgentes emiten alertas automáticas a través de OneSignal / FCM.
2. **Personalización de Tema:** Modo Oscuro o Modo Claro configurable desde `Más (⚙️) > Tema de la App`.
3. **Cierre de Sesión Seguro:** En dispositivos compartidos, cerrar sesión desde `Más (⚙️) > Cerrar Sesión`.
