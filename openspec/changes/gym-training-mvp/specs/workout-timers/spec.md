## Purpose

Guiar tiempos de ejercicio y descanso con señales diferenciadas y continuidad cuando el usuario bloquea el iPhone o cambia de aplicación.

## ADDED Requirements

### Requirement: Temporizador de ejercicio
La app SHALL distinguir visualmente ejercicio y descanso, permitir iniciar, pausar, reanudar y terminar anticipadamente una serie temporizada. Iniciar o reanudar SHALL incluir tres segundos preparatorios. SHALL admitir pausas entre sostenimientos y reinicio automático configurables.

#### Scenario: Reanudar una serie
- **WHEN** el usuario reanuda un ejercicio pausado
- **THEN** emite la preparación de tres segundos y continúa desde el tiempo restante

#### Scenario: Terminar anticipadamente
- **WHEN** el usuario termina antes una serie temporizada
- **THEN** conserva la duración realizada y pasa al descanso o transición correspondiente

### Requirement: Descansos configurables
Los descansos SHALL ser temporizados, con valores iniciales de 1:45 entre series y 2:15 entre ejercicios, configurables en rutina y por ejercicio o superserie. SHALL permitir −15 s, +15 s y terminar el descanso, solo para el descanso actual.

#### Scenario: Ejercicio pesado
- **WHEN** se configura 2:15 entre series y 3:00 entre ejercicios para un ejercicio
- **THEN** sus descansos usan esas duraciones sin modificar los valores generales

#### Scenario: Ajuste inmediato
- **WHEN** se pulsa +15 s durante un descanso
- **THEN** añade 15 segundos al restante sin cambiar descansos futuros

### Requirement: Finalización del descanso
Al vencer o terminar un descanso, la app SHALL detenerlo y dejar preparada la siguiente serie o ejercicio esperando la acción del usuario; el vencimiento SHALL emitir señal audible.

#### Scenario: Volver después del descanso
- **WHEN** el descanso vence mientras el usuario está fuera de la app y luego regresa
- **THEN** ve la siguiente serie o ejercicio en espera, sin reiniciar el descanso ni iniciar automáticamente el ejercicio

### Requirement: Continuidad y acciones bloqueadas
Los temporizadores SHALL continuar con el iPhone bloqueado o al cambiar de app. Desde la pantalla bloqueada el usuario SHALL poder completar una serie e iniciar su descanso, e iniciar, pausar y reanudar ejercicios temporizados.

#### Scenario: Serie temporizada bloqueada
- **WHEN** finaliza una serie temporizada normal con el iPhone bloqueado
- **THEN** suena la señal y comienza el descanso correspondiente sin exigir abrir la app

### Requirement: Audio diferenciado
La app SHALL emitir señales visuales y audibles diferenciadas para los eventos de temporización, incluyendo último sostenimiento y última serie. Las señales SHALL oírse por audífonos con reducción breve de la música cuando esté reproduciéndose.

#### Scenario: Última serie con audífonos
- **WHEN** termina la última serie temporizada con música en audífonos
- **THEN** emite la señal distintiva por la salida de audio activa, reduce brevemente la música y restaura su nivel

### Requirement: Transiciones por lado y superserie
En ejercicios temporizados por lado, la app SHALL cronometrar cada lado por separado y esperar el inicio del segundo tras la señal del primero. En superseries SHALL esperar el inicio del siguiente ejercicio de la ronda y descansar solo al finalizar la ronda.

#### Scenario: Primer lado
- **WHEN** termina el temporizador del primer lado
- **THEN** emite señal y deja el segundo lado en espera, sin iniciar descanso entre series

#### Scenario: Miembro intermedio de superserie
- **WHEN** termina un ejercicio temporizado y queda otro en la ronda
- **THEN** emite señal y prepara el siguiente esperando inicio, sin iniciar descanso de ronda
