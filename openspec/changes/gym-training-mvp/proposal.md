# Proposal

## Why

Reemplazar el registro manual de rutinas y cargas en Markdown por una app privada para iPhone que guíe el entrenamiento, conserve lo realmente realizado y sugiera progresión bajo control del usuario. Dos personas usarán sus propios dispositivos y cuentas de Apple, con datos independientes y entrenamiento íntegro sin conexión.

## What Changes

- Crear y editar rutinas manualmente, copiarlas o importarlas desde dos fotos con revisión humana.
- Al crear una rutina, sugerir por nombre la última carga utilizada en ese gimnasio, incluso en rutinas archivadas. Mostrar cómo se hizo el ejercicio para que el usuario decida qué carga inicial guardar.
- Gestionar gimnasios, equipos, cargas disponibles, días y ciclos; cada cambio de gimnasio archiva la rutina e inicia una nueva.
- Guiar sesiones recuperables con series, ajustes temporales, omisiones, ejercicios adicionales y superseries; finalizar parcialmente conserva el trabajo realizado.
- Ofrecer temporizadores, señales audibles y acciones con pantalla bloqueada, sujetos a validación técnica temprana en dispositivo real.
- Calcular sugerencias editables mediante saldo de esfuerzo de −2 a +2 y reglas explícitas de carga/repeticiones.
- Conservar historial, notas, cambios y cargas estimadas; incorporar respaldo/restauración en iCloud y exportación CSV.
- Distribuir privadamente mediante Ad Hoc, sin publicación en App Store.
- Ofrecer interfaz en español e inglés según el idioma del iPhone, incluyendo controles bloqueados y mensajes.
- Excluir importación Markdown, respaldo completo por archivo, funciones sociales, Android, registro de distancia/velocidad/resistencia de cardio y prescripción automática mediante IA.

## Capabilities

### New Capabilities

- `routine-cycles`: Rutinas, días, ciclos, archivo y copia.
- `gym-equipment`: Gimnasios, equipamiento, cargas y representación por ejercicio.
- `workout-sessions`: Ejecución, recuperación, ajustes, series y superseries.
- `workout-timers`: Temporizadores, descansos, audio y controles bloqueados.
- `exercise-progression`: Saldos de esfuerzo y sugerencias confirmables.
- `routine-photo-import`: Extracción conjunta de fotografías y revisión editable.
- `training-records`: Historial, notas, respaldo/restauración y CSV.
- `app-localization`: Interfaz y formatos en español e inglés según el dispositivo.

### Modified Capabilities

Ninguna; el proyecto no tiene especificaciones ni implementación previa.

## Impact

Nuevo proyecto iOS nativo en Swift/SwiftUI, almacenamiento local y servicios de Apple para iCloud y experiencia bloqueada. La importación visual podrá requerir un servicio remoto aislado del entrenamiento. Se requiere Mac con Xcode y, para Ad Hoc e iCloud, membresía Apple Developer; los dispositivos objetivo son iPhone 15 Pro e iPhone 16 actualizados. Las entregas serán flujos completos incrementales, sin eliminar requisitos del alcance inicial.
