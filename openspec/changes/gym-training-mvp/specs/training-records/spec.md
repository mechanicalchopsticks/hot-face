## Purpose

Conservar el entrenamiento real y la evolución de la rutina, con recuperación privada de datos y exportación para análisis fuera de la app.

## ADDED Requirements

### Requirement: Historial fiel
La app SHALL conservar sesiones finalizadas completas o parciales, series y valores reales, ejercicios omitidos y su vínculo con rutina y gimnasio. Modificar la rutina posteriormente no SHALL reescribir sesiones anteriores.

#### Scenario: Consulta de sesión parcial
- **WHEN** se consulta una sesión finalizada antes de completar la rutina
- **THEN** distingue lo realizado de lo no realizado y muestra las valoraciones conservadas

### Requirement: Cambios y progreso
La app SHALL registrar fecha y valores anteriores/nuevos de cambios habituales de peso, series, repeticiones, duración y sustituciones. SHALL permitir consultar progreso, marcas y notas.

#### Scenario: Sugerencia personalizada aceptada
- **WHEN** el usuario acepta una sugerencia tras editarla
- **THEN** el historial muestra los valores habituales anteriores y los valores finalmente confirmados

### Requirement: Notas editables
La app SHALL conservar notas fechadas y permitir editarlas y eliminarlas, con deshacer y rehacer durante la edición en curso.

#### Scenario: Deshacer una edición
- **WHEN** el usuario modifica una nota y deshace antes de salir de la edición
- **THEN** recupera el texto anterior y puede rehacer el cambio

### Requirement: Respaldo independiente
La app SHALL respaldar automáticamente en iCloud cuando haya conexión y permitir restaurar los datos de la cuenta correspondiente. Los datos de las dos cuentas de Apple SHALL permanecer independientes y un respaldo pendiente no SHALL impedir entrenar.

#### Scenario: Dos usuarios
- **WHEN** ambos usan sus respectivas cuentas de Apple
- **THEN** cada uno respalda y restaura únicamente su rutina, configuración e historial

#### Scenario: Recuperar conexión
- **WHEN** se han guardado entrenamientos sin conexión y vuelve la conectividad
- **THEN** permite respaldarlos sin exigir volver a registrarlos

### Requirement: Exportación CSV
La app SHALL permitir exportar manualmente entrenamientos e historial de cambios a CSV, conservando unidades, fechas, identificadores de relación y distinción entre valores desconocidos y cero.

#### Scenario: Exportar datos
- **WHEN** el usuario exporta una sesión parcial y sus cambios
- **THEN** los CSV representan series realizadas, omisiones y valores anteriores/nuevos sin convertir campos ausentes en cero
