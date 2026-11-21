# App de entrenamiento de gimnasio para iPhone

Quiero construir una app para preparar y seguir rutinas de gimnasio, registrar lo que hice y recibir sugerencias de progresión basadas en cómo se sintió cada ejercicio. Al principio la usaremos mi esposa y yo, cada uno en su propio iPhone, con rutinas, historial y respaldo independientes. El entrenamiento completo debe funcionar sin conexión.

## Rutinas, días y ciclos

- Cada rutina contiene días de entrenamiento ordenables, con ejercicios agrupados según la rutina o los grupos musculares. Los días forman un ciclo y se pueden completar en fechas distintas.
- Puedo cambiar el orden de los días. Por defecto, el cambio aplica al ciclo actual. Debe haber una opción explícita para conservar ese orden en los siguientes ciclos.
- Si salto un día, queda omitido en el ciclo actual y vuelve a estar disponible en el siguiente. El ciclo termina cuando todos los días se han completado u omitido. Los días vuelven a estar disponibles al iniciar el siguiente ciclo.
- Hay una sola rutina activa. La renovación es manual. Cuando activo una rutina nueva, la anterior se archiva junto con su historial.
- Las notas deben tener fecha y poder editarse o eliminarse. La función de deshacer y rehacer está disponible durante la edición en curso.

## Gimnasios, equipamiento y ejercicios

- Puedo crear y editar varios perfiles de gimnasio y seleccionar uno como activo. Al cambiar de gimnasio, conservo mis rutinas y el historial mantiene el gimnasio asociado a cada entrenamiento.
- Cada ejercicio puede tener nombre, variantes o indicaciones de ejecución, estación o número de máquina opcional, equipamiento, series, repeticiones o duración y peso cuando corresponda.
- Admite mancuernas, barra con discos, barras de peso fijo, máquinas selectoras, máquinas de discos, peso corporal y cardio. El cardio usa indicaciones y temporizador de duración. Distancia, velocidad y resistencia quedan fuera de ese registro.
- Admite kg y lb. Las sugerencias de carga se basan en los pesos disponibles para ese equipamiento en el gimnasio seleccionado. Para equipos cargados con discos, expresa la carga por lado y calcula los pesos posibles con las combinaciones de discos disponibles.
- Durante una sesión puedo cambiar peso, series, repeticiones, duración o sustituir un ejercicio. Por defecto, el cambio se aplica a esa sesión. Debo poder reutilizar un ajuste temporal previo o guardarlo explícitamente como configuración habitual. Una sustitución permanente queda en el historial y reinicia los contadores de esfuerzo del ejercicio.
- En la pantalla de entrenamiento, muestra el nombre, la estación cuando exista, el equipamiento, las indicaciones de ejecución y lo que corresponde hacer en la serie actual.

## Creación manual e importación desde fotos

- Puedo crear una rutina manualmente o importar juntas dos fotos, una por cada lado de una hoja de entrenamiento. La hoja puede mezclar ejercicios impresos, anotaciones manuscritas y colores para distinguir los días.
- Durante la importación, incluye los ejercicios que estén resaltados y tengan los campos correspondientes completos. Usa la tabla de días para relacionar los colores con Día 1, Día 2, etc. Usa la numeración manuscrita para ordenar los ejercicios cuando esté presente.
- Presenta los resultados en una revisión editable antes de guardar y señala los campos dudosos. Las superseries pueden definirse manualmente después. La importación desde fotos puede requerir conexión.

## Sesión de entrenamiento

- Al entrenar un día de la rutina, la app guía el ejercicio actual, cuenta las series y muestra el ejercicio siguiente durante el descanso entre ejercicios. Puedo hacer ajustes temporales desde ese flujo.
- En un ejercicio por repeticiones, marco manualmente cuándo termino cada serie. Eso incrementa el contador e inicia el descanso correspondiente.
- Si una estación está ocupada, puedo posponer el ejercicio y hacer otro pendiente. Al terminar, puedo volver al primero o seguir con otro si la estación sigue ocupada. El cambio de orden es temporal y no se registra como modificación de la rutina.
- Puedo omitir un ejercicio individual si la estación sigue ocupada o si me tengo que ir. Cuando todos los ejercicios quedan completados u omitidos, la sesión se guarda con los ejercicios omitidos identificados.
- Abandonar una sesión descarta el entrenamiento y deja el día omitido para ese ciclo. Un cierre inesperado permite recuperar la sesión activa y continuar con su avance.
- Al terminar la última serie del último ejercicio pendiente, muestra el entrenamiento terminado directamente.

## Temporizadores, descansos y superseries

- Los temporizadores de ejercicio y de descanso deben ser prominentes y fáciles de distinguir. Deben funcionar con el iPhone bloqueado. Desde la pantalla bloqueada puedo marcar una serie como completada e iniciar el descanso, e iniciar, pausar y reanudar un temporizador de ejercicio.
- Los temporizadores de ejercicio usan una cuenta preparatoria de tres segundos al iniciar o reanudar. Debo poder pausar y reanudar un ejercicio temporizado o terminar la serie antes e iniciar el descanso. Admite pausas configurables entre sostenimientos y reinicio automático configurable cuando corresponda.
- Usa señales visuales y auditivas diferenciadas, incluyendo el último sostenimiento de una serie y la última serie del ejercicio. Las señales deben poder oírse por audífonos, con una reducción breve del volumen de la música.
- Los descansos siempre son temporizados. La rutina define valores predeterminados para el descanso entre series y entre ejercicios, con ajustes por ejercicio o superserie. Al llegar a cero, el temporizador emite una señal y se detiene.
- Una superserie consiste en realizar una serie de cada ejercicio y descansar al terminar la ronda. Sus ejercicios tienen el mismo número de series y pueden tener distintas repeticiones o duraciones. Puedo guardar superseries prescritas en la rutina o agrupar ejercicios temporalmente durante una sesión, incluso de grupos distintos. Debo poder desarmar una superserie durante el entrenamiento y guardar un cambio como habitual si lo decido.

## Progresión de los ejercicios

Al terminar un ejercicio puedo marcarlo como «Fácil» o «Difícil». Dos valoraciones consecutivas del mismo tipo habilitan una sugerencia. La app debe pedir confirmación antes de aplicar cambios. La cantidad de series siempre se ajusta manualmente. En ejercicios por tiempo o con repeticiones combinadas, la sugerencia se limita a invitar a un ajuste manual, sin proponer valores.

### Después de dos «Fácil»

- Si el siguiente peso disponible supone un aumento de hasta el 10 %, inclusive, sugiere ese peso con las mismas repeticiones. Por ejemplo, 50 lb × 15 → 52,5 lb × 15.
- Si el siguiente peso supone un aumento mayor del 10 %, usa un paso previo de repeticiones con el peso actual. Los pasos de subida son 8 → 10 → 12 → 15. Después de otras dos valoraciones «Fácil», sugiere el siguiente peso y vuelve al nivel de repeticiones anterior. Por ejemplo, 35 lb × 10 → 35 lb × 12 → 45 lb × 10. Si el paso anterior fue de 12 a 15, vuelve a 12 al subir el peso.
- Si el ejercicio ya estaba en 15 repeticiones sin venir de un aumento de 12 a 15 y el siguiente peso aumenta más del 10 %, sugiere el siguiente peso con 10 repeticiones.
- Si la carga añadida actual es cero, sugiere el menor peso añadido disponible y conserva las repeticiones.
- Si no hay un peso superior, sugiere el siguiente nivel de repeticiones con la misma carga. Si ya está en 15, invita a hacer un ajuste manual.
- Cuando la carga se registra por lado, calcula el porcentaje usando la carga añadida por lado y excluye el peso de la barra o del equipo.

### Después de dos «Difícil»

- Prioriza bajar al siguiente peso disponible.
- Si no hay una carga menor, baja un nivel de repeticiones hasta un mínimo de 6, siguiendo 15 → 12 → 10 → 8 → 6.
- Si ya está en 6 y no hay una carga menor, invita a hacer un ajuste manual sin sugerir valores.

## Historial, respaldo y exportación

- Conserva los entrenamientos finalizados, los ejercicios omitidos, los valores utilizados y su vínculo con la rutina y el gimnasio correspondientes. Los entrenamientos abandonados quedan fuera del historial de sesiones.
- Conserva un historial de cambios de la rutina, como peso, series, repeticiones, duración y sustituciones, con fecha y valores anteriores y nuevos cuando corresponda. El historial debe permitir consultar el progreso, las marcas y las notas.
- Para la primera versión, usa iCloud para el respaldo y la restauración. Incluye exportación manual a CSV de los entrenamientos y del historial de cambios para analizarlos fuera de la app. El respaldo completo por archivo queda fuera del alcance inicial.

## Cómo avanzar

Usa esta especificación como base del proyecto. Si ya existe código, revisa qué está implementado y conserva las decisiones técnicas vigentes que encajen con estos requisitos. Si se parte de cero, plantea un MVP para iPhone y ordénalo por flujos que se puedan probar de principio a fin.

Antes de implementar una regla que dependa de un detalle pendiente, identifica la decisión concreta. Confirma en particular qué reinicia las valoraciones consecutivas cuando cambia la configuración de un ejercicio, aparte del reinicio ya definido para una sustitución permanente. Incluye criterios de aceptación para los ciclos, la recuperación de sesiones, los temporizadores con pantalla bloqueada y los ejemplos de progresión.