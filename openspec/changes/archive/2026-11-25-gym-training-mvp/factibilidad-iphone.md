# Factibilidad en iPhone

## Tarea 1.6 · Resultado frente a workout-timers

**21 de noviembre de 2026.** En el iPhone 15 Pro con iOS 27.0.1 se demostraron los controles bloqueados y la transición de una serie al descanso. Para las señales con música, las notificaciones locales son la vía candidata. Los ensayos de controles y audio se hicieron por separado. El iPhone 16 con iOS 26 sigue pendiente de prueba física. [Especificación de temporizadores](specs/workout-timers/spec.md)

| Requisito | Evidencia disponible | Comprobación pendiente |
|---|---|---|
| Temporizador de ejercicio | En el iPhone bloqueado se distinguieron preparación, ejercicio y descanso. Al reanudar, hubo 3 s de preparación y se conservó el tiempo restante. En el Mac se comprobó el paso a descanso al terminar antes y la pausa configurable entre sostenimientos con reinicio manual o automático. | Guardar la duración realmente ejecutada al terminar antes (5.1) y comprobar el reinicio manual de sostenimientos en el iPhone (5.4). |
| Descansos configurables | El prototipo de controles usa un descanso fijo de 15 s. | Probar 1:45 entre series y 2:15 entre ejercicios, ajustes de rutina, ejercicio y superserie, y los controles −15 s, +15 s y terminar. Comprobar que solo cambia el descanso actual y que el restante nunca es negativo (5.2). |
| Finalización del descanso | Tras el vencimiento con el iPhone bloqueado, la siguiente serie quedó esperando un toque. En el simulador se recuperó esa espera después de cambiar de app. | Comprobar en el iPhone, en un mismo ensayo fuera de la app, el tono de fin de descanso y la fase al volver. Repetir al terminar manualmente y al pasar al siguiente ejercicio (5.2–5.3). |
| Continuidad y acciones bloqueadas | Con permisos concedidos, el usuario inició, pausó, reanudó y completó desde la actividad en vivo. Un toque inició un único descanso. El ciclo automático observado duró 38 s. Una prueba independiente recuperó tres series de SwiftData tras escrituras concurrentes y reintentos. | Verificar el ciclo integrado durante suspensión prolongada y con cada permiso denegado. Los ensayos de cierre forzado y reinicio documentan la fase al volver. La terminación por iOS sigue sin observación (5.3, 5.6–5.7). |
| Audio diferenciado | Hay seis señales con textos y sonidos distintos, incluidos último sostenimiento y última serie. Con notificaciones locales, el usuario distinguió tonos al cambiar de app. En el ensayo con el iPhone bloqueado oyó el tono por los audífonos. El usuario confirmó que, tras la bajada de volumen, la música volvía a su nivel anterior. Un ensayo anterior quedó en silencio. Con AlarmKit, la alarma salió por el altavoz y detuvo la música. | Identificar el tono y el aviso visual del último sostenimiento y de la última serie, tanto en bloqueo como en otra app. Registrar permisos, silencio, concentración y salida en ambos iPhone (5.6–5.7). |
| Transiciones por lado y superserie | El reloj de prueba modela la espera por un inicio explícito. Los ensayos cubrieron series y sostenimientos. | Probar que al vencer el primer lado suena la señal y el segundo espera. En una ronda, el miembro intermedio debe dejar al siguiente en espera y el descanso debe empezar solo tras el último (5.4–5.5). |

**Criterio para la integración.** Usar los resultados de ActivityKit y App Intents como base de los controles. Evaluar notificaciones locales con sonido para el bloqueo y la sesión de audio breve en primer plano. El control de volumen de `duckOthers` corresponde a la sesión de audio de la app. La ruta y la recuperación del volumen de una notificación se deben comprobar por escucha. [Sonidos de notificación](https://sosumi.ai/documentation/usernotifications/unnotificationsound) · [Reducción temporal del volumen](https://sosumi.ai/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/duckothers)

La evidencia descarta el sonido de AlarmKit para el escenario ensayado con música y audífonos. Ningún requisito ha demostrado ser inviable. Si la prueba integrada en cualquiera de los dos iPhone reproduce el silencio o la interrupción de la música, registrar los ajustes y el resultado y resolver la alternativa con el usuario antes de incorporar ese comportamiento.

## Registro del 20 de noviembre de 2026

| Comprobación | Resultado observado |
|---|---|
| `sw_vers` y `xcrun swift --version` | macOS 26.6.2 (25G83), Apple Silicon, Swift 6.4. |
| Xcode | Xcode 27.2 (27B52) en `/Applications/Xcode.app`. La selección global sigue apuntando a las herramientas de línea de comandos. |
| SDK | La instalación incluye iPhoneOS 27.2 y iPhoneSimulator 27.2, además de `simctl` y `devicectl`. La compilación para simulador terminó correctamente usando el ejecutable de Xcode completo. |
| iPhone del usuario | iPhone 15 Pro físico, iOS 27.0.1 (24A446), emparejado por cable. Xcode indica que el modo de desarrollador está activado. |
| iPhone de su esposa | iOS 26 según el usuario. |

Los modelos objetivo, iPhone 15 Pro e iPhone 16, son [compatibles con iOS 26](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-26-iphe3fa5df43/26). El prototipo usa iOS 26.0 como versión mínima tanto en la app como en la extensión. Queda pendiente leer la versión exacta del segundo teléfono cuando se empareje.

## Prueba de compilación y arranque

El proyecto `HotFace/HotFace.xcodeproj` compila con Xcode 27.2 y el SDK de simulador 27.2. Se instaló en un iPhone 18 Pro simulado con iOS 27.2. El registro de instalación confirmó la app y la extensión WidgetKit. `simctl launch` devolvió el proceso 17694 para `ejemplo.entrenamiento.prueba`. Los dos paquetes declaran iOS 26.0 como mínimo.

Desde Xcode, seleccionar el esquema **HotFace**, elegir un simulador de iPhone y ejecutar con el argumento de arranque `-workout-probe`. La pantalla ofrece iniciar y finalizar una actividad en vivo de una serie de sentadillas ficticia. Los identificadores de paquete son provisionales para la prueba.

## Firma de la prueba

- **Simulador.** El entorno disponible y utilizado es iOS 27.2. El proyecto declara iOS 26.0 como mínimo y la verificación en esa versión sigue pendiente.
- **Instalación de desarrollo.** Emparejar ambos iPhone con Xcode y habilitar el modo de desarrollador. Seleccionar el mismo equipo para la app y la extensión, asignarles identificadores de paquete distintos y habilitar el mismo App Group en ambos. Comprobar que los perfiles de desarrollo incluyen los dispositivos y el grupo, y que se dispone del certificado Apple Development con su clave privada. Xcode admite la firma automática. [Perfiles de desarrollo](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile/)
- **Distribución Ad Hoc.** El diseño indica que la membresía de Apple Developer está pendiente. Se necesitan membresía activa, los dos dispositivos registrados por UDID, certificado Apple Distribution con su clave privada y perfiles Ad Hoc para los identificadores y capacidades de la app y su extensión. [Distribución Ad Hoc](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/)

El Mac dispone de una identidad Apple Development válida. La app y la extensión tienen firma automática y el mismo equipo de desarrollo. Se conservaron los identificadores de paquete registrados al traducir el proyecto. La compilación para el iPhone 15 Pro terminó correctamente y la verificación de firma de la app y su extensión pasó en el Mac. La instalación en el iPhone tuvo éxito. Tras el rechazo inicial, el segundo intento de arranque tuvo éxito. Xcode confirmó que el prototipo seguía en ejecución en el iPhone físico (PID 972).

## Tarea 1.3 · Controles y temporizadores

Se compiló el prototipo para dispositivo y simulador con Xcode 27.2. En el iPhone 15 Pro con iOS 27.0.1, `devicectl` confirmó la instalación y el arranque de esta versión. El paquete incluye el motivo de uso de AlarmKit y los metadatos de `WorkoutIntent` en la app y la extensión.

La prueba usa 3 segundos de preparación, 20 de ejercicio y 15 de descanso. Al iniciar o reanudar, la app programa en AlarmKit dos avisos con fechas fijas, uno al terminar la serie y otro al terminar el descanso. La actividad en vivo recibe esas fechas para representar la fase durante el bloqueo. Pausar cancela los avisos y conserva el tiempo de ejercicio restante. Completar manualmente programa el fin del descanso desde el momento del toque.

| Prueba | Resultado |
|---|---|
| Transiciones con reloj controlado en el Mac | A los 3 s empieza el ejercicio, a los 23 s empieza el descanso y a los 38 s la serie 2 queda en espera. |
| Pausa y reanudación con reloj controlado | Pausar a los 9 s conserva 14 s de ejercicio. Reanudar añade 3 s de preparación. Pausar durante la preparación conserva los 20 s completos. |
| Finalización manual con reloj controlado | Completar una serie inicia 15 s de descanso. Otro toque durante ese descanso no completa una segunda serie. |
| Permisos efectivos en el teléfono | En esta versión, **Iniciar actividad** comprueba que las actividades en vivo están habilitadas y que AlarmKit devuelve autorización antes de crear la actividad. El ensayo en el iPhone llegó a la serie temporizada. La app muestra ambos estados en **Permisos**. |
| Pantalla desbloqueada, versión inicial | En el iPhone 15 Pro, el usuario observó que el descanso terminaba y la pantalla seguía mostrando «Descanso 0:00». |
| Pantalla bloqueada, versión inicial | El usuario observó que la preparación terminaba y la actividad en vivo seguía mostrando «Prepárate 0:00». Los temporizadores continuaban en segundo plano. |
| Pantalla desbloqueada, versión revisada | En el simulador iOS 27.2, una prueba de interfaz de la vista con datos de ensayo observó la serie 2 en espera tras completar la primera y esperar 15 s. Al iniciar la segunda, comprobó preparación, ejercicio, descanso y serie 3 en espera. No hubo interacción al vencer los temporizadores. La prueba aisló la vista porque el simulador mostraba el permiso de alarmas denegado. |
| Pantalla bloqueada, versión revisada | En el iPhone 15 Pro con iOS 27.0.1, el usuario confirmó que vio preparación, ejercicio, descanso y el paso automático a la siguiente serie sin abrir la app. Las duraciones configuradas eran 3, 20 y 15 segundos, respectivamente. |
| Reanudación con pantalla bloqueada | Antes de la corrección, la actividad se quedaba en «Prepárate 0:00». Tras instalarla en el iPhone 15 Pro con iOS 27.0.1, el usuario confirmó que, al pausar y reanudar, «Prepárate» cambia a «Ejercicio» tras los 3 segundos y la cuenta continúa desde el tiempo restante. |

La versión revisada calcula la fase de la app abierta con el reloj cada segundo. Para la pantalla bloqueada, la app publica el contenido de cada fase cuando puede ejecutarse e indica a iOS cuándo caduca esa presentación. La extensión prepara la fase correspondiente al vencimiento. El ensayo físico cubrió un ciclo de 38 s con bloqueo normal. La suspensión prolongada y la terminación por el sistema siguen pendientes de ensayo. [Actualizaciones de actividades en vivo](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

Para repetir las comprobaciones de tiempos desde la raíz del proyecto:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path TrainingKit --filter WorkoutTimelineTests
```

Para repetir la prueba, tocar **Iniciar actividad**, bloquear el iPhone y encender la pantalla. Desde la actividad en vivo, iniciar, pausar durante el ejercicio y reanudar. Dejar vencer la serie sin tocar el teléfono. Tras el descanso, pulsar **Completar serie** en la siguiente serie y comprobar que comienza un solo descanso. En la app, **Finalizar actividad** cancela las alarmas de la prueba.

## Matriz de comprobación física

Usar series ficticias. En cada celda registrar la versión de iOS, el permiso efectivo de AlarmKit, la disponibilidad de actividades en vivo y lo observado. Registrar por separado el instante de la señal, la fase visible antes de abrir la app y la fase recuperada al abrirla.

| Condición | Observación que se debe recoger | iPhone del usuario · iOS 27 | iPhone de su esposa · iOS 26 |
|---|---|---|---|
| Pantalla bloqueada | Completar desde la actividad en vivo, iniciar, pausar y reanudar. Observar preparación, tiempo restante y avance de serie. | El usuario confirmó el inicio, la pausa, la reanudación y el descanso automático. También confirmó que un toque en «Completar serie» inicia un único descanso de 15 s y que, al vencer, aparece la siguiente serie. | Pendiente |
| Cambio de app | Dejar vencer la serie fuera de la app. Comprobar si el descanso comienza a su hora y si al vencer suena y deja la siguiente serie en espera. | El usuario distinguió los tonos fuera de la app. Los intervalos exactos y la fase al volver quedaron sin confirmar en este ensayo. | Pendiente |
| Sostenimientos, música y audífonos | Repetir con pantalla bloqueada y en otra app. Distinguir último sostenimiento de última serie, comprobar pausa y reinicio configurados, salida por audífonos, reducción de música y recuperación de volumen. | Con notificaciones locales y el iPhone bloqueado, el usuario oyó el tono por los audífonos y la música bajó de volumen sin detenerse y después volvió a su nivel anterior. Con AlarmKit, el tono salió por el altavoz y la música se detuvo. | Pendiente |
| Permisos denegados | Repetir denegando AlarmKit y desactivando por separado las actividades en vivo. Anotar qué alertas llegan, qué controles aparecen y qué acciones se guardan. | Pendiente | Pendiente |
| Terminación por el sistema | Registrar cómo se identificó la terminación y qué alerta, actividad y estado persistido sobreviven. | Pendiente | Pendiente |
| Cierre forzado por el usuario | Cerrar desde el selector durante una serie. Registrar señal y controles antes de reabrir, y fase recuperada después. | Al volver, el usuario vio «Iniciar segunda serie». Cree haber oído todos los tonos. | Pendiente |
| Reinicio del teléfono | Reiniciar durante una serie. Registrar alertas y estado tras el arranque y después del primer desbloqueo. | Al abrir por primera vez vio el temporizador de descanso. Al volver de nuevo apareció «Iniciar segunda serie». | Pendiente |
| Escrituras simultáneas y recuperación | Enviar desde app y extensión dos acciones para la misma serie, reabrir el almacén SwiftData del grupo y contar una sola serie. Repetir con dos series distintas y comprobar que persisten ambas. | Verificado el 21 de noviembre. Tras relanzar la app y reintentar, persistieron exactamente las series 1, 2 y 3 con sus autores. | Pendiente |

**Resultado de la tarea 1.4.** En el iPhone 15 Pro, las notificaciones locales sonaron por los audífonos durante el bloqueo y la música recuperó su volumen tras la bajada temporal. El usuario distinguió los tonos al cambiar de app. Después del cierre forzado y del reinicio, el prototipo volvió a ofrecer «Iniciar segunda serie». La matriz detalla las observaciones de cada ensayo. La comprobación en el iPhone 16 sigue pendiente.

## Tarea 1.4 · Prueba de audio con sostenimientos

El 20 de noviembre se compiló, instaló y abrió el prototipo en el iPhone 15 Pro con iOS 27.0.1. En el Mac pasaron las pruebas del reloj para dos series, pausa configurable, arranque automático y manual del último sostenimiento, fin del descanso y recuperación del plan guardado. El paquete instalado contiene seis sonidos PCM mono distintos de 0,18 a 0,96 s. El análisis de las muestras confirmó tres notas descendentes al terminar el último sostenimiento de la primera serie y cuatro ascendentes al terminar la segunda serie. El iPhone 16 sigue pendiente de conexión.

En el simulador iOS 27.2 pasó una prueba de interfaz del modo de notificaciones. Tras enviar la app a inicio durante 27 s, la segunda serie estaba lista y esperaba un toque. Tras iniciarla, terminar el proceso desde XCTest y reabrirlo 19 s después, apareció «Última serie terminada». XCTest registró una advertencia de posible bloqueo al activar o desactivar la sesión de audio en el hilo principal. La prueba verificó la fase recuperada, sin medir sonido ni volumen.

### Ensayo reproducible

En **Prueba de audio con sostenimientos**, iniciar con música de otra app en los audífonos. En **Método de audio**, elegir **Alarmas del sistema** y permitir AlarmKit para reproducir la segunda prueba. Para reproducir la primera, elegir **Notificaciones locales** y permitir notificaciones con sonido. El método de la serie aparece en la misma sección mientras está en curso. Conservar el modo de silencio y concentración que se desea ensayar y anotarlo. Si hay una actividad de sentadillas abierta, finalizarla primero. El ensayo usa dos series ficticias de dos sostenimientos, con inicio manual de cada serie.

| Desde el inicio de cada serie | Aviso visible | Sonido esperado |
|---|---|---|
| 3 s | Primer sostenimiento | Una nota |
| 9 s | Pausa entre sostenimientos | Dos notas graves iguales |
| 12 s | Último sostenimiento | Dos notas ascendentes |
| 18 s, serie 1 | Último sostenimiento terminado · Descanso | Tres notas descendentes |
| 26 s, serie 1 | Descanso terminado · Siguiente serie en espera | Tres notas iguales. La segunda serie espera un toque. |
| 18 s, serie 2 | Última serie terminada | Cuatro notas ascendentes. Termina el ensayo. |

Los tiempos de la tabla corresponden a sostenimientos de 6 s, pausa de 3 s y reinicio automático. **Finalizar prueba de audio** permite repetirla y cancela los avisos de ese ensayo. Para comprobar el modo manual, elegir otra pausa y desactivar el reinicio automático. Tras la pausa, el último sostenimiento debe esperar el toque y sus 3 s de preparación.

La primera versión programa notificaciones locales con sonidos propios para que iOS pueda presentarlas durante el bloqueo y el cambio de app. En primer plano intenta reproducir la misma muestra con una sesión de audio que solicita reducir la música y se desactiva al acabar. En segundo plano, la ruta de salida y el efecto sobre la música se comprueban escuchando. Al reabrir, la fase se calcula con las fechas guardadas. Registrar por separado lo que sonó y la fase calculada. [Sonidos de notificación](https://developer.apple.com/documentation/usernotifications/unnotificationsound) · [Reducción de volumen](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/duckothers)

Se confirmó la ejecución de la segunda versión en el mismo iPhone. Permite programar las mismas fechas y muestras con AlarmKit. Cada ejecución usa un solo mecanismo. Conviene anotar si una alarma permanece sonando y si tapa el siguiente tono. [Configuración del sonido de AlarmKit](https://developer.apple.com/videos/play/wwdc2025/230/)

Para aislar la hipótesis del Mac, repetir el ensayo de notificaciones con la misma música y ruta, cambiando solo **Mostrar en la Mac** en los ajustes de notificaciones del prototipo. Registrar primero el valor original y restaurarlo tras comparar. [Notificaciones del iPhone en el Mac](https://support.apple.com/es-es/120684)

Al revisar el iPhone tras la escucha que interrumpió la música, el prototipo conservaba un ensayo con `holdTrialUsesAlarms = true`. La versión utilizada ocultaba el selector durante la prueba. El valor efectivo de **Mostrar en la Mac** no se registró.

### Matriz de resultados de audio

Para cada ejecución anotar el mecanismo elegido, su permiso efectivo, modo de concentración/silencio, salida, notas oídas, si la música bajó y volvió a su volumen, último aviso visible y fase al reabrir. Repetir el bloqueo y el cambio de app en ambas series para comparar el último sostenimiento con la última serie en las mismas condiciones.

| Condición | Qué observar | iPhone 15 Pro · 27.0.1 | iPhone 16 · iOS 26 |
|---|---|---|---|
| Pantalla desbloqueada | Tono, ruta de audio, reducción y recuperación del volumen | El usuario oyó los tonos en la primera prueba. Ruta, música y patrón concreto pendientes de confirmación. | Pendiente |
| Primer ensayo con bloqueo normal, notificaciones | Bloquear tras iniciar. Identificar cada tono y aviso antes de desbloquear | **Fallo observado.** El usuario informó que el iPhone bloqueado quedó en silencio. El posible envío al Mac queda por verificar. | Pendiente |
| Bloqueo normal, notificaciones locales seleccionadas | Salida del tono, volumen de la música y presentación | El usuario oyó el tono por los audífonos. La música siguió sonando, bajó de volumen durante el aviso y después volvió al nivel anterior. Observó que se acumulaban los banners. Había cambiado **Previsualizar** de **Si desbloqueaste** a **Siempre**. | Pendiente |
| Repetición con AlarmKit, pantalla desbloqueada y bloqueo normal | Escuchar con la misma música y los audífonos | En ambos estados el tono salió por el altavoz y la música se detuvo por completo en los audífonos. El ensayo guardado usaba AlarmKit. | Pendiente |
| Bloqueo normal, AlarmKit | Salida de audio, efecto sobre la canción y fin del aviso | **Fallo observado.** Con los audífonos conectados, la alarma sonó por el altavoz del iPhone. El usuario oyó que la canción se pausaba y se adelantaba. La alarma siguió sonando hasta que deslizó el control en pantalla. | Pendiente |
| Cambio de app | Mantener otra app al frente durante los avisos. Anotar tono, música y fase al volver | El usuario distinguió los tonos y estimó 5–6 s entre avisos. El plan guardado en el iPhone para la serie 2 usaba notificaciones locales y fijaba los avisos a los 3, 9, 12 y 18 s desde el inicio. Los intervalos exactos y la fase al volver siguen pendientes de comprobación. | Pendiente |
| Reinicio manual del sostenimiento | Comprobar espera tras la pausa elegida y aviso tras iniciar el último sostenimiento | Pendiente en dispositivo | Pendiente |
| Cierre forzado | Deslizar el prototipo fuera del selector tras iniciar. Esperar el fin de la serie antes de reabrir. Anotar avisos, audio y fase recuperada | Con notificaciones locales, el usuario confirmó que al reabrir apareció «Iniciar segunda serie». Cree haber oído todos los tonos durante el cierre. La entrega de cada aviso quedó sin verificar individualmente. | Pendiente |
| Reinicio del teléfono | Activar sostenimientos de 90 s. Reiniciar tras la primera señal. Registrar hora de arranque, primer desbloqueo, avisos recibidos o perdidos y fase al abrir | Tras reiniciar, el usuario oyó dos tonos separados. Al abrir vio el temporizador de descanso. Salió, oyó otros dos tonos seguidos y al volver vio «Iniciar segunda serie». Recuerda posibles avisos de fin de descanso y fin de serie. Los textos, su orden y los tiempos exactos quedaron sin confirmar. | Pendiente |
| Terminación por iOS | Si se observa, anotar la evidencia de terminación y qué avisos llegaron | Sin observación | Sin observación |

**Previsualización.** Apple describe este ajuste como control de la visibilidad del contenido en la pantalla bloqueada. El ensayo no aisló su efecto sobre el audio. [Guía de notificaciones del iPhone](https://support.apple.com/es-es/108781)

**Ajuste de los avisos tras la escucha.** La revisión asigna los avisos de sostenimientos a un mismo grupo para la presentación de iOS. Al volver a la app, retira los avisos ya entregados de esa prueba. En primer plano la fase aparece en la pantalla de la serie y se reproduce el tono sin solicitar un banner. Queda por observar la presentación en el iPhone con los ajustes actuales de agrupación. [Agrupación de notificaciones](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/threadidentifier)

Prueba del reloj desde la raíz del proyecto:

```sh
swiftc HotFace/App/HoldTrial.swift HotFace/Tests/HoldTrialChecks.swift -o /tmp/hold-trial-checks
/tmp/hold-trial-checks
```

## Tarea 1.5 · SwiftData compartido y recuperación

Cada ensayo usa una sesión ficticia identificada por UUID en el App Group `group.ejemplo.entrenamiento.prueba`. La app y la extensión WidgetKit abren el mismo archivo SwiftData. La app guarda el identificador del ensayo en el grupo, solicita una actividad en vivo y envía una notificación Darwin. El proceso de WidgetKit lee el comando pendiente al arrancar o al recibir la notificación. Una marca exclusiva permite que una sola instancia de la extensión lo ejecute. Antes de cada escritura, ambos procesos anuncian que su acción está en curso y esperan a la otra parte. El ensayo comprueba los identificadores de proceso y de paquete de ambos escritores.

Las dos acciones intentan completar la serie 1. Después, la app completa la serie 2 mientras la extensión completa la 3. Cada escritor coordina la consulta y el guardado con `NSFileCoordinator`, abre un contexto nuevo y conserva el autor original de la serie. Tras terminar y relanzar la app, se leen las filas desde disco, se reintentan las tres acciones y se vuelven a verificar los números y autores. [Contenedor compartido](https://sosumi.ai/documentation/foundation/filemanager/containerurl(forsecurityapplicationgroupidentifier:)) · [Configuración de SwiftData](https://sosumi.ai/documentation/swiftdata/modelconfiguration)

| Entorno | Misma serie | Series distintas | Recuperación y reintento |
|---|---|---|---|
| iPhone 15 Pro físico, iOS 27.0.1 | La extensión (PID 1371) guardó la serie 1. La app (1373) reconoció que ya existía. | La app guardó la 2 y la extensión la 3. | Tras relanzar, la app (1375) recuperó las tres series y sus autores. Repetir los tres comandos conservó exactamente esas filas. |
| iPhone 18 Pro simulado, iOS 27.2 | La app (PID 27481) guardó la serie 1. La extensión (27485) reconoció que ya existía. | La app guardó la 2 y la extensión la 3. | El nuevo lector (27515) verificó las mismas tres filas antes y después del reintento. |

El 21 de noviembre de 2026, los informes de concurrencia y recuperación del ensayo `2303E2BB-7B21-4CFD-95C4-F03F66C5A17D` devolvieron `PASS` en ambos entornos. Las versiones que iniciaban la escritura al construir la vista de la actividad habían pasado cinco ensayos en simulador. En el iPhone agotaron la espera antes de que la extensión anunciara su primera escritura.

### Repetir en un iPhone conectado

Con esta versión de HotFace instalada y las actividades en vivo habilitadas, elegir un UUID nuevo para cada ensayo. Ejecutar en el Mac con el iPhone desbloqueado:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
device="iPhone"
bundle="ejemplo.entrenamiento.prueba"
trial=$(uuidgen)
xcrun devicectl device process launch --device "$device" --terminate-existing "$bundle" -- -storage-trial "$trial"
```

Cuando termine la actividad de prueba, leer el resultado de concurrencia. Si empieza por `PASS`, relanzar el proceso con el mismo UUID y leer su resultado de recuperación:

```sh
xcrun devicectl device copy from --device "$device" --domain-type appDataContainer --domain-identifier "$bundle" --source "Documents/$trial-race.txt" --destination "/tmp/$trial-race.txt"
cat "/tmp/$trial-race.txt"
xcrun devicectl device process launch --device "$device" --terminate-existing "$bundle" -- -recover-storage-trial "$trial"
xcrun devicectl device copy from --device "$device" --domain-type appDataContainer --domain-identifier "$bundle" --source "Documents/$trial-recovery.txt" --destination "/tmp/$trial-recovery.txt"
cat "/tmp/$trial-recovery.txt"
```

Ambos informes deben indicar `PASS`. El de recuperación debe mostrar un proceso lector nuevo, las series 1, 2 y 3 y `replay=true`. Si la copia se solicita antes de que aparezca el informe, repetir el comando de copia.
