# AppClub - Asoc. Deportiva Inf. y Juv. Jorge Newbery 🏆⚽

Aplicación móvil oficial de la **Asociación Deportiva Infantil y Juvenil Jorge Newbery**, desarrollada en **Flutter** para Android e iOS. 

AppClub es una plataforma integral de gestión institucional, comunicación, administración deportiva y comunidad para clubes deportivos.

---

## 📱 Módulos y Funcionalidades Principales

- 👥 **Gestión de Roles y Permisos**:
  - **Tutor / Madre / Padre**: Vinculación y seguimiento de jugadores menores de edad.
  - **Socio**: Acceso a beneficios, tienda y carnet digital.
  - **Jugador**: Consulta de estadísticas, fixture, convocatorias y citaciones.
  - **Entrenador / D.T.**: Control de asistencias, carga de convocados, alineaciones y gestión de partidos.
  - **Directivo / Admin**: Panel de control general, aprobación de socios, gestión de categorías, sponsors e ingresos.

- 🗓️ **Fixture y Resultados**:
  - Visualización de calendario de partidos, tablas de posiciones y reporte de goleadores.
  - Gestión en tiempo real del estado de los partidos.

- 📣 **Comunicación y Novedades**:
  - Muro social interactivo con publicaciones, imágenes y comentarios.
  - Comunicados oficiales con notificaciones.

- 💳 **Pagos y Gestión Financiera**:
  - Registro de cuotas sociales, actividades y aranceles.
  - Descarga e historial de comprobantes de pago.

- 🛒 **Tienda Oficial del Club**:
  - Catálogo de indumentaria y productos institucionales con detalle de talles y compra directa.

- 🛡️ **Cumplimiento Legal y Privacidad (Google Play Ready)**:
  - Términos y Condiciones y Política de Privacidad integrados en la app.
  - Opción directa de **Eliminación de Cuenta** conforme a la normativa 2024 de Google Play Console.

---

## 🚀 Tecnologías Utilizadas

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.44.4)
- **Lenguaje**: Dart (^3.12)
- **Gestión de Estado**: [Flutter Riverpod](https://riverpod.dev/)
- **Backend & Cloud**:
  - [Firebase Auth](https://firebase.google.com/docs/auth) (Email/Contraseña y Google Sign-In)
  - [Cloud Firestore](https://firebase.google.com/docs/firestore) (Base de datos NoSQL en tiempo real)
  - [Firebase Storage](https://firebase.google.com/docs/storage) (Almacenamiento multimedia)
  - [Cloud Functions](https://firebase.google.com/docs/functions) (Lógica de servidor)
- **Diseño & UI**:
  - Sistema de diseño personalizado (`JNButton`, `JNCard`, `JNAvatar`)
  - `google_fonts` (Tipografía Inter/Outfit)
  - `flutter_animate` (Animaciones y micro-interacciones)
  - `fl_chart` (Gráficos estadísticos)

---

## 🛠️ Requisitos e Instalación Local

### Prerrequisitos
- **Flutter SDK**: 3.22.0 o superior ([Guía de instalación](https://docs.flutter.dev/get-started/install))
- **Android Studio / VS Code** con plugins de Flutter y Dart.
- **Java Development Kit (JDK)**: versión 17.

### Pasos para Ejecutar
1. **Clonar el repositorio**:
   ```bash
   git clone https://github.com/munozalbelonicolas/AppClub.git
   cd AppClub
   ```

2. **Instalar dependencias**:
   ```bash
   flutter pub get
   ```

3. **Verificar servicios de Firebase**:
   - Asegúrate de contar con el archivo `android/app/google-services.json` configurado para tu proyecto de Firebase.

4. **Ejecutar en modo Desarrollo**:
   ```bash
   flutter run
   ```

---

## 📦 Compilación para Google Play Console (Prueba Cerrada)

Para generar el archivo **Android App Bundle (.aab)** optimizado para subir a la **Prueba Cerrada (Closed Testing)** de Google Play Console:

### 1. Configurar Llave de Firma (Keystore) - Opcional para Release firmado localmente
Crea un archivo `android/key.properties` con la siguiente estructura:
```properties
storePassword=tu_contraseña_keystore
keyPassword=tu_contraseña_llave
keyAlias=tu_alias
storeFile=C:/ruta/a/tu/upload-keystore.jks
```
*(Si no se encuentra `key.properties`, Gradle utilizará la firma debug para compilación local).*

### 2. Generar el App Bundle (.aab)
Ejecuta el siguiente comando en la terminal:
```bash
flutter build appbundle --release
```
El archivo resultante se generará en:
`build/app/outputs/bundle/release/app-release.aab`

---

## 📋 Requisitos para la Prueba Cerrada en Google Play Console

Al crear la versión en **Google Play Console**, completa los siguientes puntos:
1. **Ficha de la Tienda**: Subir captura de pantalla, ícono (512x512) y descripción.
2. **Política de Privacidad**: Usar la URL de política de privacidad institucional.
3. **Declaración de Seguridad de Datos (Data Safety)**:
   - Recopilación de datos: Nombre, Email, Teléfono, Fotos (imágenes de perfil/publicaciones).
   - Todos los datos son transferidos con cifrado SSL/TLS.
4. **Verificación de Eliminación de Cuenta**: La app incluye la opción en *Configuración > Eliminar mi cuenta*.
5. **Prueba Cerrada (20 Testers)**: Si la cuenta de desarrollador es personal (creada después de nov 2023), requiere al menos 20 probadores registrados durante 14 días continuos.

---

## 📄 Licencia y Propiedad

© Asociación Deportiva Infantil y Juvenil Jorge Newbery. Todos los derechos reservados.
