# QA Plan - AppClub

## 1. Objetivo
Establecer los lineamientos, alcance y metodologías para asegurar la calidad del software (AppClub) antes de cada lanzamiento a producción.

## 2. Alcance
- Pruebas Funcionales (Login, Registro, Reservas, Tienda, etc.)
- Pruebas No Funcionales (Rendimiento, Pérdida de red)
- Pruebas de Roles y Permisos (Admin vs User)

## 3. Estrategia de Pruebas
- **Smoke Testing:** Para validar los flujos críticos (Happy Paths) en cada nuevo build.
- **Regression Testing:** Pruebas profundas previas a cada release oficial.
- **UAT (User Acceptance Testing):** Validación final orientada al usuario.

## 4. Criterios de Aceptación (DoD)
- 0 Bugs Críticos o Altos.
- Smoke Tests aprobados al 100%.
- Funcionalidades cumplen con el diseño y experiencia especificados.
