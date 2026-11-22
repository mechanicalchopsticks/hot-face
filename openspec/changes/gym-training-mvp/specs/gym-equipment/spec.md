## Purpose

Representar el equipamiento de cada gimnasio y las cargas elegidas por el usuario sin confundir unidades, estimaciones y formas de visualización.

## ADDED Requirements

### Requirement: Cambio de gimnasio
La app SHALL permitir crear y editar gimnasios y seleccionar uno activo. Todo cambio de gimnasio SHALL archivar la rutina activa e iniciar la creación de una nueva con saldos en cero, conservando el historial y su gimnasio original.

#### Scenario: Regresar a un gimnasio conocido
- **WHEN** el usuario vuelve a un gimnasio anterior
- **THEN** no reactiva automáticamente su rutina antigua; inicia una nueva, que puede copiar de una archivada

### Requirement: Eliminar un gimnasio
La app SHALL permitir eliminar un gimnasio desde Ajustes. Antes de confirmar, SHALL identificar el gimnasio e indicar que dejará de estar disponible para entrenar y que se conservará su historial. Cancelar SHALL conservar el catálogo y la selección actuales.

#### Scenario: Eliminar un gimnasio inactivo
- **WHEN** el usuario confirma la eliminación de un gimnasio inactivo
- **THEN** ese gimnasio y sus equipos desaparecen de los selectores, incluso después de reabrir la app
- **AND** el gimnasio y la rutina activos siguen seleccionados, y las sesiones y rutinas archivadas del gimnasio eliminado se pueden consultar con su gimnasio y equipo originales

#### Scenario: Eliminar el gimnasio activo
- **WHEN** el usuario elimina el gimnasio activo y quedan otros gimnasios
- **THEN** elige el gimnasio de reemplazo antes de confirmar, se archiva la rutina activa si existe y se inicia la creación de una rutina con saldos en cero en el gimnasio elegido
- **AND** si hay una sesión abierta en el gimnasio que se quiere eliminar, puede continuarla o finalizarla y solo puede confirmar la eliminación después de finalizarla

#### Scenario: Eliminar el último gimnasio
- **WHEN** el usuario confirma la eliminación del único gimnasio tras finalizar cualquier sesión abierta
- **THEN** se archiva la rutina activa si existe y Ajustes muestra el catálogo vacío con la opción de crear un gimnasio
- **AND** el historial sigue disponible y crear un gimnasio con el mismo nombre le da una identidad nueva

### Requirement: Equipamiento disponible
La app SHALL representar mancuernas, barra con discos, barras fijas, máquinas selectoras, máquinas de discos, peso corporal, bandas y cardio. Las cargas disponibles SHALL pertenecer al equipamiento del gimnasio seleccionado.

#### Scenario: Seleccionar equipo
- **WHEN** se elige una barra con discos o una máquina de discos en dos ejercicios del mismo gimnasio
- **THEN** ambos consultan los mismos tamaños de disco y cada ejercicio conserva su propia carga habitual

### Requirement: Eliminar un equipo
La app SHALL permitir eliminar un equipo desde los Ajustes de su gimnasio. Antes de confirmar, SHALL identificar el equipo y su gimnasio. Cancelar SHALL conservar el equipo y sus asignaciones.

#### Scenario: Retirar una máquina del catálogo
- **WHEN** el usuario confirma la eliminación de una máquina
- **THEN** la máquina desaparece del catálogo y de los selectores de equipo, incluso después de reabrir la app
- **AND** se conservan los inventarios compartidos, los demás equipos y los registros históricos con la estación, las cargas y las unidades originales

#### Scenario: El equipo estaba asignado a un ejercicio
- **WHEN** se elimina un equipo utilizado en una rutina vigente
- **THEN** el ejercicio conserva su prescripción y muestra el equipo como eliminado para que el usuario pueda reemplazarlo antes de volver a usarlo
- **AND** una sesión ya iniciada conserva la copia de la prescripción con la que empezó y puede finalizarse

### Requirement: Inventario inicial editable por gimnasio
Cada gimnasio nuevo SHALL comenzar con inventarios editables de discos, mancuernas individuales y barras fijas. El usuario SHALL poder añadir, editar y quitar pesos en Ajustes del gimnasio. Cada ejercicio SHALL poder elegir del inventario correspondiente a su equipo. Cada entrada SHALL conservar su unidad original.

#### Scenario: Crear un gimnasio
- **WHEN** el usuario crea un gimnasio
- **THEN** sus inventarios contienen estos pesos iniciales

| Inventario | Pesos iniciales |
|---|---|
| Discos | 2,5 · 5 · 10 · 25 · 35 · 45 lb |
| Mancuernas individuales en lb | 2,5 · 5 · 10 · 15 · 20 · 25 · 30 · 35 · 40 · 50 · 60 · 70 · 80 · 90 · 100 |
| Mancuernas individuales en kg | 5 · 7,5 · 10 · 12,5 |
| Barras fijas (barra Z), peso total en kg | 10 · 15 · 20 · 25 · 30 · 35 · 40 · 50 |

#### Scenario: Compartir una edición
- **WHEN** se añade una mancuerna de 22,5 lb y se quitan los discos de 2,5 y 5 lb de un gimnasio
- **THEN** todos sus ejercicios de mancuernas ofrecen 22,5 lb y sus barras y máquinas de discos calculan con los tamaños restantes
- **AND** el inventario de otro gimnasio conserva sus propios valores

#### Scenario: Elegir una mancuerna o una barra fija
- **WHEN** se configura un ejercicio con el inventario inicial
- **THEN** para mancuernas puede elegirse tanto una pieza de 10 lb como una de 10 kg, y para barra fija puede elegirse una barra de 10 kg por su peso total

### Requirement: Cargas alcanzables con discos
El selector de carga y las sugerencias de progresión SHALL usar las sumas simétricas alcanzables con los tamaños de disco del gimnasio. Cada tamaño se registra una vez y puede repetirse en la suma. El usuario elige la combinación física que cabe. El máximo inclusivo SHALL ser 500 lb añadidas entre ambos lados, sujeto al máximo opcional de carga añadida por lado del equipo.

#### Scenario: Configurar el peso propio de una barra
- **WHEN** el usuario añade una barra con discos
- **THEN** su peso propio comienza en 45 lb y se puede editar independientemente de los límites de carga añadida

#### Scenario: Peso alcanzable frente a peso imposible
- **WHEN** se usa el inventario inicial en una barra o máquina de discos con capacidad para al menos 30 lb añadidas
- **THEN** 30 lb añadidas (10 + 5 lb por lado) están disponibles para el selector y la progresión, y ambos descartan 31 lb añadidas por ser inalcanzables

#### Scenario: Límite del equipo y peso propio
- **WHEN** una barra de 45 lb admite hasta 90 lb añadidas por lado
- **THEN** admite dos discos de 45 lb por lado, equivalentes a 180 lb añadidas y 225 lb incluyendo la barra, y descarta cualquier carga añadida superior a 180 lb
- **AND** con el inventario inicial y sin un máximo específico, admite 500 lb añadidas (545 lb incluyendo la barra) y descarta 505 lb añadidas

### Requirement: Máquinas selectoras en pasos de 5 kg
Para una máquina selectora con incrementos de 5 kg, la app SHALL ofrecer las 30 cargas desde 5 hasta 150 kg inclusive, en pasos de 5 kg.

#### Scenario: Elegir una carga de la máquina selectora
- **WHEN** se elige esta máquina para un ejercicio
- **THEN** el selector incluye 5, 10 y 150 kg y excluye 0, 7,5 y 155 kg, independientemente del inventario de discos

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
