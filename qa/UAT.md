# User Acceptance Testing (UAT)

*Pruebas diseñadas para ser ejecutadas por usuarios reales (Ej. Dirigentes del club, Entrenadores).*

## Escenario 1: Organización de un Partido
**Actor:** Entrenador (DT)
**Pasos:**
1. Crear un partido para el fin de semana.
2. Hacer la convocatoria de 11 jugadores.
3. Jugador X ingresa y confirma asistencia.
4. DT cierra la convocatoria.
**Criterio de Éxito:** El sistema refleja el estado en tiempo real sin crashear y las notificaciones llegan.

## Escenario 2: Compra en la Tienda
**Actor:** Jugador / Socio
**Pasos:**
1. Navegar a la Tienda.
2. Seleccionar camiseta talle M.
3. Confirmar pedido ("Pendiente de pago").
4. Subir comprobante (imagen).
5. Admin aprueba el pago.
**Criterio de Éxito:** El pedido cambia a "A Revisar" y luego a "Confirmado".
