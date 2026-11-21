## Purpose

Organizar rutinas personales en días y ciclos independientes del calendario, conservando las versiones archivadas.

## ADDED Requirements

### Requirement: Rutina activa y creación
La app SHALL permitir crear manualmente, editar y copiar rutinas con días ordenables y ejercicios agrupados, manteniendo una sola rutina activa.

#### Scenario: Copiar una rutina anterior
- **WHEN** el usuario copia y activa una rutina archivada
- **THEN** conserva estructura y configuración, inicia historial y saldos nuevos y mantiene intacta la original
- **AND** archiva la rutina previamente activa con su historial

### Requirement: Ciclos independientes de fechas
La app SHALL completar el ciclo cuando todos sus días estén completados u omitidos y disponer de nuevo de todos los días al iniciar el siguiente ciclo.

#### Scenario: Omitir un día
- **WHEN** el usuario omite un día y termina los restantes en fechas distintas
- **THEN** el ciclo termina y el día omitido vuelve a estar disponible en el siguiente

#### Scenario: Finalización parcial
- **WHEN** el usuario finaliza una sesión con ejercicios pendientes
- **THEN** el día queda completado en el ciclo sin trasladar los pendientes a otro día

### Requirement: Orden temporal de días
La app SHALL aplicar los cambios de orden de días solo al ciclo actual, salvo elección explícita de conservarlos en ciclos futuros.

#### Scenario: Reordenar sin guardar como habitual
- **WHEN** el usuario mueve el Día 3 delante del Día 2 para el ciclo actual
- **THEN** el siguiente ciclo conserva el orden habitual anterior

### Requirement: Renovación manual
La app SHALL mantener la rutina activa entre ciclos hasta que el usuario la reemplace o cambie de gimnasio.

#### Scenario: Terminar un ciclo
- **WHEN** termina el último día del ciclo
- **THEN** no se archiva ni reemplaza automáticamente la rutina
