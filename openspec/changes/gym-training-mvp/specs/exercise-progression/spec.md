## Purpose

Proponer progresión reproducible a partir de las valoraciones voluntarias del usuario y del equipamiento disponible, manteniendo la decisión final en sus manos.

## ADDED Requirements

### Requirement: Saldo de esfuerzo
La app SHALL mantener un saldo entre −2 y +2: Fácil suma uno y Difícil resta uno, saturando en los extremos. No valorar SHALL conservarlo. El usuario SHALL poder valorar ejercicios parcialmente realizados y sesiones con ajustes temporales.

#### Scenario: Valoración opuesta
- **WHEN** el saldo es +2 y el usuario marca Difícil
- **THEN** queda +1 y desaparece la sugerencia pendiente de aumento

#### Scenario: Sin valoración y límite
- **WHEN** se registran Fácil, sin valorar, Fácil y Fácil
- **THEN** los saldos sucesivos son +1, +1, +2 y +2

### Requirement: Reinicio por cambios habituales
La app SHALL reiniciar el saldo al cambiar habitualmente peso, repeticiones, series o duración, aceptar una sugerencia o sustituir permanentemente un ejercicio. Ajustes temporales, orden, notas y conversiones de visualización no SHALL reiniciarlo.

#### Scenario: Ajuste temporal valorado
- **WHEN** el saldo es +1 y se registra Fácil tras usar temporalmente otra carga
- **THEN** queda +2 manteniendo intacta la configuración habitual

### Requirement: Sugerencia al inicio y confirmación editable
Con saldo +2 o −2, la app SHALL sugerir al iniciar el ejercicio usando su configuración habitual y cargas disponibles. SHALL permitir editar la propuesta antes de aceptarla. Aceptar SHALL guardar los valores finales como habituales, registrar el cambio y reiniciar el saldo; continuar sin aceptar SHALL conservarlo.

#### Scenario: Rechazar y volver
- **WHEN** el usuario continúa con valores actuales y no cambia su saldo de +2
- **THEN** vuelve a recibir la sugerencia al próximo inicio sin acumular otras dos valoraciones

#### Scenario: Personalizar sugerencia
- **WHEN** la app propone 35 lb × 12 y el usuario confirma 35 lb × 11
- **THEN** guarda 35 lb × 11 como habitual y deja el saldo en cero

#### Scenario: Base habitual
- **WHEN** la sesión anterior usó temporalmente 25 lb × 15 pero lo habitual es 35 lb × 10
- **THEN** calcula la sugerencia desde 35 lb × 10

### Requirement: Aumento pequeño de peso
Con saldo +2, si el siguiente peso disponible aumenta hasta un 10 % inclusive, la app SHALL proponer ese peso conservando las repeticiones.

#### Scenario: Incremento pequeño
- **WHEN** lo habitual es 50 lb × 15 y el siguiente peso es 52,5 lb
- **THEN** propone 52,5 lb × 15

#### Scenario: Límite inclusivo
- **WHEN** lo habitual es 50 lb × 10 y el siguiente peso es 55 lb
- **THEN** propone 55 lb × 10

### Requirement: Paso intermedio de repeticiones
Si el siguiente peso aumenta más de 10 %, la app SHALL proponer primero el siguiente escalón de 8, 10, 12, 15, conservar el peso y recordar las repeticiones anteriores. Tras aceptar y volver a +2 SHALL proponer el siguiente peso volviendo al valor anterior.

#### Scenario: Puente de diez a doce
- **WHEN** se parte de 35 lb × 10, el siguiente peso es 45 lb y se acepta 35 lb × 12
- **THEN** al alcanzar nuevamente +2 propone 45 lb × 10

#### Scenario: Puente de doce a quince
- **WHEN** se aceptó un paso de 12 a 15 repeticiones para preparar un aumento de carga
- **THEN** al volver a +2 propone subir la carga y volver a 12

#### Scenario: Quince sin puente previo
- **WHEN** lo habitual es 15 repeticiones sin provenir de un paso de 12 a 15 y el siguiente peso aumenta más de 10 %
- **THEN** propone el siguiente peso con 10 repeticiones

### Requirement: Límites de carga y escalones
Con saldo +2 y carga añadida cero, la app SHALL proponer el menor peso añadido disponible conservando repeticiones. Sin peso superior SHALL proponer el siguiente escalón hasta 15 o invitar a ajuste manual si no existe. Para repeticiones fuera de escala SHALL elegir el siguiente escalón en la dirección correspondiente.

#### Scenario: Nueve repeticiones
- **WHEN** corresponde aumentar repeticiones desde 9
- **THEN** propone 10; si corresponde reducir desde 9, propone 8

#### Scenario: Sin carga superior
- **WHEN** no existe carga mayor y lo habitual es 12 repeticiones
- **THEN** propone 15 con la misma carga; si ya estaba en 15 invita a ajuste manual

### Requirement: Reducción por dificultad
Con saldo −2, la app SHALL priorizar el siguiente peso menor conservando repeticiones. Sin peso menor SHALL bajar repeticiones siguiendo 15, 12, 10, 8, 6; sin escalón inferior permitido SHALL invitar a ajuste manual.

#### Scenario: Carga mínima
- **WHEN** no existe peso menor y lo habitual es 10 repeticiones
- **THEN** propone 8 con la misma carga

#### Scenario: Límite inferior
- **WHEN** no existe peso menor y lo habitual es 6 repeticiones
- **THEN** invita a ajustar manualmente sin inventar valores

### Requirement: Porcentajes por lado
Cuando se registra carga por lado, la app SHALL calcular el porcentaje con la carga añadida por lado, excluyendo barra o equipo, independientemente de la vista seleccionada.

#### Scenario: Barra excluida
- **WHEN** la carga añadida es 10 kg por lado y el siguiente valor es 12,5 kg por lado
- **THEN** considera un aumento del 25 %, aunque la barra pese 20 kg

### Requirement: Ajustes manuales especiales
La app SHALL dejar siempre las series bajo ajuste manual. Para ejercicios por tiempo o repeticiones combinadas SHALL invitar a un ajuste manual al alcanzar un extremo, sin proponer valores.

#### Scenario: Repeticiones combinadas
- **WHEN** un ejercicio de 7+7+7 alcanza +2
- **THEN** invita a revisar manualmente su configuración sin convertirlo a 21 ni sugerir nuevos valores
