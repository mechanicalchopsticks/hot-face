## Purpose

Guiar el entrenamiento sin conexión y conservar cada avance, distinguiendo la configuración habitual de lo realmente realizado.

## ADDED Requirements

### Requirement: Entrenamiento íntegro sin conexión
La app SHALL permitir iniciar, registrar, ajustar, recuperar y finalizar entrenamientos sin conexión. La pantalla SHALL mostrar ejercicio, estación opcional, equipamiento, indicaciones y prescripción de la serie actual.

#### Scenario: Sesión sin red
- **WHEN** el usuario entrena sin conexión
- **THEN** todos los avances se guardan localmente y el respaldo pendiente no bloquea la sesión

### Requirement: Registro rápido de series
La app SHALL registrar los valores mostrados e iniciar el descanso correspondiente con un toque en Completar serie, permitiendo corregir la serie durante el descanso. Una serie por lado SHALL incluir ambos lados.

#### Scenario: Repeticiones por lado
- **WHEN** termina 10 repeticiones por cada lado y pulsa Completar serie
- **THEN** registra una sola serie de 10 por lado e inicia el descanso correspondiente

### Requirement: Ajustes de sesión
La app SHALL permitir cambiar peso, series, repeticiones, duración y ejercicio, reutilizar ajustes temporales previos y añadir ejercicios de cualquier grupo. Los ajustes SHALL afectar solo a la sesión salvo guardado explícito como habituales.

#### Scenario: Ejercicio adicional
- **WHEN** el usuario añade un ejercicio durante el entrenamiento sin guardarlo como habitual
- **THEN** aparece en la sesión y su historial, pero no en el siguiente ciclo

#### Scenario: Guardar una sustitución
- **WHEN** el usuario guarda una sustitución como habitual
- **THEN** se registra el cambio permanente y se reinicia el saldo del ejercicio sustituido

### Requirement: Orden y omisiones
La app SHALL permitir posponer, seleccionar otro ejercicio pendiente, volver al pospuesto y omitir ejercicios. Cambiar el orden de sesión SHALL dejar intacto el orden habitual.

#### Scenario: Estación ocupada
- **WHEN** el usuario pospone un ejercicio, hace otro y regresa al primero
- **THEN** conserva el progreso de ambos sin registrar una modificación de rutina

### Requirement: Finalización parcial conserva el trabajo
La app SHALL cerrar definitivamente una sesión al finalizarla, conservar series y valoraciones realizadas, marcar lo restante como no realizado y completar el día del ciclo. No SHALL descartar el entrenamiento por estar incompleto.

#### Scenario: Salir antes de terminar
- **WHEN** el usuario finaliza tras dos series de un ejercicio de cuatro series
- **THEN** conserva las dos series, permite valorar ese ejercicio parcial y no deja pendientes para otra sesión

#### Scenario: Último ejercicio
- **WHEN** termina la última serie del último ejercicio pendiente, estando los demás completados u omitidos
- **THEN** muestra entrenamiento terminado directamente, sin descanso final innecesario

### Requirement: Recuperación de sesión abierta
La app SHALL conservar el avance tras un cierre inesperado y permitir continuar o finalizar una sesión abierta incluso en otra fecha. Bloquear el teléfono o salir de la app no SHALL finalizarla.

#### Scenario: Recuperar al día siguiente
- **WHEN** el usuario abre la app al día siguiente de un cierre con sesión pendiente
- **THEN** ofrece continuar con el avance guardado o finalizar lo realizado; solo la finalización completa el día

### Requirement: Superseries
La app SHALL permitir superseries habituales o temporales, incluso entre grupos distintos, con igual número de series y distintas repeticiones o duraciones. Cada ronda SHALL incluir una serie de cada miembro y descansar al final. SHALL permitir desarmarlas y guardar explícitamente cambios habituales.

#### Scenario: Crear agrupación incompatible
- **WHEN** se agrupan ejercicios con diferente número de series
- **THEN** requiere resolver el número común antes de activar la superserie

#### Scenario: Desarmar durante la sesión
- **WHEN** el usuario desarma una superserie
- **THEN** conserva las series realizadas y deja disponibles las restantes de cada ejercicio sin duplicarlas

### Requirement: Cardio
La app SHALL representar cardio mediante indicaciones y temporizador de duración, sin registrar distancia, velocidad ni resistencia en el alcance inicial.

#### Scenario: Cardio prescrito
- **WHEN** se inicia un ejercicio de cardio de 15 minutos
- **THEN** muestra sus indicaciones y un temporizador de duración
