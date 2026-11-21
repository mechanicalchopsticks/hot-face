## Purpose

Convertir dos caras de una hoja de entrenamiento en una rutina revisable, conservando indicaciones y haciendo visibles los datos incompletos o inciertos.

## ADDED Requirements

### Requirement: Extracción conjunta
La app SHALL importar juntas dos fotos, combinando texto impreso, manuscrito, colores y numeración. SHALL incluir ejercicios resaltados con prescripción y detectar candidatos manuscritos sin color para revisión. La importación podrá requerir conexión sin afectar el entrenamiento.

#### Scenario: Ambas caras
- **WHEN** un día tiene ejercicios repartidos entre las dos fotos
- **THEN** los reúne en un mismo día y los ordena según la numeración manuscrita

### Requirement: Leyenda propia de la hoja
La app SHALL obtener la relación color/día de la tabla de cada hoja, sin reutilizar una equivalencia universal.

#### Scenario: Naranja cambia de día
- **WHEN** la primera rutina asigna naranja a Día 4 y la tercera a Día 2
- **THEN** cada importación respeta su propia leyenda

### Requirement: Revisión antes de guardar
La app SHALL presentar todos los resultados editables antes de guardar, señalar texto dudoso, datos tachados, orden ausente y días sin asignar. No SHALL inventar cargas ni interpretar MAQ como peso. Las superseries SHALL poder definirse manualmente después.

#### Scenario: Estación tachada
- **WHEN** importa Sentadilla máquina de la tercera rutina con MAQ ilegible
- **THEN** señala la estación para revisión sin copiar silenciosamente el número de otra hoja

#### Scenario: Sin numeración
- **WHEN** un abdominal tiene color pero no orden
- **THEN** reconoce su día y deja el orden para revisión

### Requirement: Abdomen sin día
Para el gimnasio de estas hojas, la app SHALL sugerir Día 1 para abdominales sin día asignado, marcado por confirmar. Una asignación explícita SHALL tener prioridad; esta convención no SHALL aplicarse universalmente a otros gimnasios.

#### Scenario: Omisión de color
- **WHEN** importa Plancha y Pallof press sin color de la primera rutina
- **THEN** los incluye como candidatos a Día 1 por confirmar en lugar de descartarlos

### Requirement: Prescripción fiel
La app SHALL distinguir segundos, repeticiones por lado y segmentos combinados, conservar variantes e indicaciones, y presentar notas generales para revisión sin inventar su distribución cuando sea ambigua.

#### Scenario: Formatos de las hojas
- **WHEN** lee 40″, 12 c/u y 7+7+7 con una indicación de ejecución
- **THEN** conserva respectivamente duración, repeticiones por lado y tres segmentos junto con su indicación

#### Scenario: Cardio general
- **WHEN** lee cardio todos los días mínimo 15 minutos
- **THEN** presenta esa prescripción para incorporarla a todos los días sin inventar equipo ni posición en la sesión
