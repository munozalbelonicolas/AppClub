# Casos de Prueba Detallados

## Formato Estándar
| ID | Módulo | Caso de prueba | Objetivo | Precondiciones | Datos | Pasos | Resultado esperado | Resultado obtenido | Estado | Severidad | Prioridad | Responsable | Observaciones |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC001 | Login | Login exitoso | Validar acceso correcto | Usuario registrado | email/pass válido | 1. Abrir app. 2. Llenar email. 3. Llenar pass. 4. Tap 'Ingresar' | Redirige al Dashboard | Pendiente | Pendiente | Alta | Alta | QA | - |
| TC002 | Login | Credenciales Inválidas | Validar rechazo | N/A | email/pass erróneo | 1. Ingresar datos falsos. 2. Tap 'Ingresar' | Muestra error 'Credenciales inválidas' | Pendiente | Pendiente | Media | Alta | QA | - |
| TC003 | Registro | Crear nuevo usuario | Validar registro | App instalada | email nuevo | 1. Tap Registro. 2. Llenar datos. 3. Confirmar | Cuenta creada y sesión iniciada | Pendiente | Pendiente | Alta | Alta | QA | - |
| TC004 | Red | Offline mode | Validar tolerancia a fallos | Sesión activa | N/A | 1. Apagar WiFi/Datos. 2. Abrir app | Muestra mensaje de "Sin conexión" pero no crashea | Pendiente | Pendiente | Media | Media | QA | - |
| TC005 | Reservas | Duplicado | Evitar doble reserva | Usuario con saldo | ID Evento | 1. Reservar cupo. 2. Intentar reservar mismo cupo | Error "Ya estás inscrito" | Pendiente | Pendiente | Alta | Media | QA | - |
| TC006 | Permisos | Modificar Evento (Jugador) | Validar roles | Sesión jugador | N/A | 1. Abrir calendario. 2. Intentar editar | Botón oculto o error de permisos | Pendiente | Pendiente | Crítica | Alta | QA | - |

> *Nota: Este documento debe ser clonado a una hoja de cálculo (Excel/Google Sheets) para el seguimiento diario.*
