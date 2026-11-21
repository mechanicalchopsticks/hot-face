## Purpose

Representar el equipamiento de cada gimnasio y las cargas elegidas por el usuario sin confundir unidades, estimaciones y formas de visualización.

## ADDED Requirements

### Requirement: Cambio de gimnasio
La app SHALL permitir crear y editar gimnasios y seleccionar uno activo. Todo cambio de gimnasio SHALL archivar la rutina activa e iniciar la creación de una nueva con saldos en cero, conservando el historial y su gimnasio original.

#### Scenario: Regresar a un gimnasio conocido
- **WHEN** el usuario vuelve a un gimnasio anterior
- **THEN** no reactiva automáticamente su rutina antigua; inicia una nueva, que puede copiar de una archivada

### Requirement: Equipamiento disponible
La app SHALL representar mancuernas, barra con discos, barras fijas, máquinas selectoras, máquinas de discos, peso corporal, bandas y cardio. Las cargas disponibles SHALL pertenecer al equipamiento del gimnasio seleccionado.

#### Scenario: Combinaciones de discos
- **WHEN** se configura el inventario de discos y la carga simétrica por lado
- **THEN** los pesos posibles respetan las cantidades de discos disponibles para ambos lados

### Requirement: Representación de carga por ejercicio
La app SHALL guardar por ejercicio la unidad kg/lb y su representación: por mancuerna o total combinado, por lado o total añadido y, cuando se conozca, total incluyendo barra/equipo. Cambiar la representación SHALL conservar la carga física y el saldo.

#### Scenario: Dos mancuernas
- **WHEN** se cambia de 10 kg por mancuerna a total de dos mancuernas
- **THEN** muestra 20 kg sin registrar una progresión ni reiniciar el saldo

#### Scenario: Peso de barra desconocido
- **WHEN** se solicita el total incluyendo una barra cuyo peso no está definido
- **THEN** pide definir ese peso en lugar de inventarlo

### Requirement: Carga estimada y confirmación
La app SHALL distinguir carga sin definir, estimada y habitual confirmada. Entrenar con una carga estimada SHALL registrar el valor utilizado sin confirmarlo automáticamente.

#### Scenario: Primera serie con estimación
- **WHEN** el usuario completa una serie con 20 lb estimadas
- **THEN** conserva 20 lb en la serie y la estimación permanece hasta confirmación explícita

#### Scenario: Ausencia de peso
- **WHEN** un ejercicio importado carece de carga
- **THEN** queda sin definir, distinto de un cero explícito

### Requirement: Carga inicial basada en el historial del gimnasio
Al crear una rutina, la app SHALL sugerir sin conexión la carga de la última serie realizada con peso registrado en el mismo gimnasio para un ejercicio del mismo nombre. SHALL considerar las rutinas archivadas y sesiones finalizadas parcialmente. El usuario podrá confirmar la carga, editarla antes de confirmar o dejarla sin definir.

#### Scenario: Última serie válida entre varias rutinas
- **WHEN** el último peso registrado para ese nombre en el gimnasio fue 35 kg en una sesión parcial hace tres rutinas, después se omitió el ejercicio y se usaron 40 kg en otro gimnasio
- **THEN** propone 35 kg aunque hayan cambiado estación, variante o repeticiones

#### Scenario: Contexto para decidir
- **WHEN** el ejercicio anterior era 4 × (7+7+7) con 35 kg y el nuevo indica 3 × 8
- **THEN** muestra ambas prescripciones, la fecha anterior, la carga con su unidad y, si existen, la estación y las indicaciones anteriores, sin mostrar el gimnasio
- **AND** si el usuario edita la sugerencia a 30 kg y confirma, guarda 30 kg como carga inicial y el saldo nuevo empieza en cero

#### Scenario: Sin historial en este gimnasio
- **WHEN** el nuevo ejercicio carece de carga inicial y solo tiene series con peso en otro gimnasio
- **THEN** la carga queda sin definir
