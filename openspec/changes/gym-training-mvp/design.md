# Design

## Context

Ver proposal.md para motivación y capacidades. Proyecto nuevo, sin código previo. Fuentes: documento de requisitos original, ejemplos de hojas rutina1/rutina3 y decisiones de la conversación. Las decisiones posteriores sustituyen tres reglas originales: saldo cancelable en lugar de rachas consecutivas; cierre parcial conserva lo realizado; cambio de gimnasio exige nueva rutina.

Dispositivos objetivo: iPhone 15 Pro e iPhone 16 con iOS actualizado. Distribución privada Ad Hoc acordada; todavía no hay membresía Apple Developer. Cada usuario tiene su propia cuenta de Apple. La interfaz debe funcionar en español e inglés.

## Goals / Non-Goals

**Goals:** Separar reglas deterministas de servicios de iOS, persistir avances incrementales y mantener historial inmutable frente a cambios de prescripción. El grupo 1 valida la factibilidad técnica con el iPhone bloqueado. Tras el grupo 3, la primera experiencia de uso que se diseña y prueba es Entrenar con el iPhone desbloqueado.

**Non-Goals:** Un servidor como dependencia del entrenamiento, cuentas compartidas, traducción automática de notas, importación de Markdown y un motor de recomendaciones basado en IA.

## Decisions

### Entrega por pestaña a partir del cierre del grupo 3

El primer prototipo se abre desde Entrenar en el iPhone con un día precargado a partir de rutina1 o rutina3. Usa cargas de ejemplo y mantiene el avance en memoria. Durante la prueba, el usuario puede consultar la serie actual, completarla, corregir lo realizado durante el descanso, pasar al siguiente ejercicio y revisar el resumen. Se ajusta el recorrido con lo observado durante una sesión de prueba.

Una vez definida la experiencia desbloqueada, se prueba la misma sesión de ejemplo con el iPhone bloqueado para decidir qué información y acciones tener a mano entre series. Después se conectan las interacciones acordadas a los comandos, repositorios y servicios de iOS y se verifica el recorrido con almacenamiento real.

Para cada flujo pendiente de Rutinas, Historial y Ajustes se repite el ciclo en su pestaña: probar una UI interactiva con fixtures, incorporar las observaciones del usuario y conectar la lógica y el almacenamiento necesarios. Se aprovechan las pantallas y capacidades entregadas en los grupos anteriores. Los datos de ejemplo se mantienen separados de las rutinas y sesiones del usuario.

### 1. App nativa y módulos

La app se llama HotFace. Swift y SwiftUI, con iOS 26 como base técnica propuesta para AlarmKit; verificar SDK y versiones instaladas antes de crear el proyecto. Una solución web o multiplataforma no elimina el trabajo nativo de temporizadores, audio y controles bloqueados, por lo que añade complejidad para un producto exclusivamente iPhone.

- Dominio Swift independiente: ciclos, prescripción, sesiones, saldos, sugerencias y combinaciones de discos.
- Persistencia: repositorios que almacenan dominio y cambios.
- Adaptadores: reloj, audio, AlarmKit, ActivityKit/App Intents, iCloud e importación.
- Interfaz: Entrenar, Rutinas e Historial; Ajustes para gimnasios, respaldo y exportación.
- Pantalla de sesión centrada en serie actual, con lista accesible para reordenar, omitir, añadir y agrupar.

### 2. Modelo y persistencia

SwiftData es la opción inicial, tras verificar persistencia y extensiones en una prueba pequeña. Frente a archivos Markdown permite consultas, relaciones y evolución de esquema. No activar sincronización CloudKit del almacén completo por defecto: el alcance acordado es respaldo/restauración independiente, no edición simultánea multidispositivo.

Entidades principales:

| Entidad | Datos relevantes |
|---|---|
| Gimnasio | Identidad e inventario compartido de mancuernas individuales, tamaños de disco y barras fijas. Cada peso incluye su unidad |
| Equipo | Identidad, estación, tipo, peso propio y máximo opcional de carga añadida por lado para barras y máquinas de discos |
| Rutina/revisión | Gimnasio, estado activa/archivada, días ordenados, configuración habitual |
| Ejercicio prescrito | Nombre, variantes, equipo, series, segmentos de repeticiones/tiempo, lateralidad, descansos |
| Ciclo/día | Referencia a rutina, orden efectivo, pendiente/completado/omitido |
| Sesión | Copia de prescripción al iniciar, gimnasio, progreso, abierta/finalizada, fechas |
| Serie realizada | Valores reales, lados/segmentos, duración, completada/parcial y correcciones |
| Valoración | Ejercicio, sesión, valor, fecha y vínculo al estado de progresión |
| Progresión | Saldo −2…+2, configuración base, puente de repeticiones pendiente |
| Cambio/nota | Fecha, valores anteriores/nuevos, origen y contenido editable |

Guardar cada acción antes de confirmar su éxito en pantalla. Un comando repetido desde pantalla bloqueada debe ser idempotente y no duplicar una serie o valoración. Usar identificadores persistentes y serialización de escrituras entre app y extensiones mediante almacenamiento compartido y un único coordinador lógico.

Una sesión guarda una instantánea, por lo que editar o archivar la rutina no cambia el historial. Correcciones de series modifican lo realizado, no la configuración habitual. El cierre parcial es una finalización, no un rollback. Una sesión abierta conserva todos sus avances incluso si se recupera otro día.

### 3. Cargas y progresión

Al crear una rutina manual, copiada o importada, el editor consulta el historial local por identificador de gimnasio y nombre del ejercicio realizado. Dentro de ese gimnasio basta el nombre. La estación, las repeticiones y el equipo sirven de contexto. Seleccionar la serie realizada más reciente con carga registrada según el momento de ejecución, incluyendo sesiones finalizadas parcialmente y rutinas archivadas. Usar el peso real con su unidad y representación, incluidas correcciones y cargas de cero. Descartar series omitidas y campos vacíos.

El editor muestra la fecha y la prescripción de aquella sesión junto al ejercicio nuevo. Conserva los segmentos de repeticiones, la estación y las indicaciones disponibles y omite el nombre del gimnasio. La sugerencia es opcional y editable. Solo la confirmación escribe el valor elegido como carga inicial. En una copia, la carga copiada se puede conservar o sustituir explícitamente. Sin carga inicial ni coincidencia, el campo queda sin definir. El saldo de la nueva rutina empieza en cero.

Al crear el gimnasio, inicializar una sola vez los tres inventarios editables definidos en gym-equipment. Ajustes edita esos valores y cada ejercicio consulta el inventario de su gimnasio según el equipo. Guardar cada peso con precisión decimal y su unidad de origen para que puedan coexistir mancuernas en kg y lb. Al guardar la prescripción, conservar el peso elegido, su representación y el número de implementos. Así, una mancuerna usada por ambos lados sigue contando como una pieza.

El editor y la progresión consultan las mismas cargas disponibles. Para barras fijas se usa el peso total de cada pieza. Para máquinas selectoras de paso de 5 kg se generan 5, 10, …, 150 kg. Para barras y máquinas de discos, calcular las sumas alcanzables por lado permitiendo repetir tamaños, y duplicarlas para obtener los totales añadidos. Detener el cálculo en el menor de 250 lb por lado y el límite configurado del equipo, comparados en la misma unidad. El ajuste expresa un límite práctico de peso. La elección de discos que caben físicamente corresponde al usuario. Sumar el peso propio únicamente para la vista que incluye el equipo (45 lb iniciales editables para una barra con discos). La progresión por lado usa solo el peso añadido.

Al migrar los datos de 3.1, reunir por gimnasio y tipo las mancuernas, las barras fijas y los tamaños de disco ya registrados con sus unidades. Un tamaño repetido en varios equipos genera una entrada compartida. Usar los pesos de las entradas de discos para obtener sus tamaños y conservar por separado las cargas de equipo preexistentes cuyo significado sea distinto. Preservar los pesos propios personalizados, las referencias al equipo y las instantáneas históricas. Aplicar los valores iniciales de un gimnasio nuevo una sola vez para que las ediciones sobrevivan a la reapertura.

El motor recibe configuración habitual, saldo, cargas disponibles y antecedente del puente. Devuelve sugerencia estructurada y motivo localizable, o invitación a ajuste manual; nunca aplica cambios directamente.

El puente de repeticiones es distinto del saldo: aceptar un paso de 10 a 12 reinicia el saldo pero conserva 10 como retorno previsto al subir peso. Propuesta de implementación conservadora: una edición personalizada que ya no coincide con el puente lo invalida; vuelve a evaluarse la configuración final como nueva base. Esta política debe mostrarse en revisión de diseño antes de implementar ese caso.

No generar valores numéricos cuando falta una carga base o el inventario necesario; pedir completar datos. Para repeticiones por encima del escalón máximo, evitar reducirlas bajo una sugerencia de aumento: ofrecer ajuste manual si no hay un paso aplicable. Los ejercicios temporizados y combinados usan invitación manual según las especificaciones.

### 4. Temporización y controles bloqueados

Persistir estado, instante de finalización, tiempo restante al pausar, segmento/lado/ronda y siguiente transición. La UI calcula el restante desde el reloj; un contador en memoria no es la fuente de verdad.

Estados: preparación, ejercicio activo, pausa, espera de segundo lado, espera de siguiente miembro, descanso, siguiente serie/ejercicio en espera y sesión finalizada. Evaluar la transición mediante el mismo dominio desde app y acciones bloqueadas.

Probar ActivityKit y App Intents para representación/acciones, AlarmKit para alertas gestionadas por iOS y AVAudioSession para señales breves con duckOthers. Una Live Activity visible no garantiza ejecución de código al vencer un tramo; no tratar un callback de UI como garantía de transición.

La primera entrega técnica debe demostrar en dispositivo: preparación, sostenimientos, paso automático a descanso, señal de fin, controles bloqueados, música/audífonos y recuperación. Diferenciar bloqueo, cambio de app, terminación por el sistema, cierre forzado y reinicio del teléfono. No usar audio silencioso continuo para mantener la app viva. Si las APIs no permiten un requisito acordado, detener esa parte y presentar evidencia y alternativa al usuario; no degradarlo silenciosamente.

Referencias oficiales revisadas durante la exploración:
- https://developer.apple.com/videos/play/wwdc2025/230/
- https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/duckothers

### 5. Respaldo y restauración

Usar almacenamiento local como fuente operativa y copias completas versionadas en la base privada de CloudKit, mediante manifiesto de esquema y assets. Frente a sincronización automática de entidades, las copias permiten restaurar un estado anterior sin propagar inmediatamente una eliminación.

Propuesta técnica inicial: conservar la última copia válida y un pequeño conjunto de anteriores, con política de retención configurable internamente y documentada antes de lanzamiento. Preparar snapshots consistentes localmente, subir el contenido y publicar el manifiesto solo al finalizar. Nunca mostrar respaldo exitoso antes de confirmación del servicio.

Al restaurar: descargar, validar versión/integridad, migrar en un almacén temporal y sustituir el local solo tras validación, conservando una copia de seguridad previa. La interfaz informa fecha de última copia y pendientes. Manejar cuenta iCloud ausente, cambio de cuenta, falta de espacio y red sin bloquear el entrenamiento ni mezclar datos de cuentas.

La política exacta de retención puede decidirse durante implementación sin cambiar el contrato de respaldo. No ofrecer exportación del respaldo completo como archivo en esta versión.

### 6. Importación visual aislada

Adaptador de extracción de dos imágenes hacia un esquema estructurado: candidatos, día/color, orden, prescripción, detalles y campos dudosos con referencia a la fuente. Un borrador de importación no modifica la rutina activa.

Evaluar un proveedor de visión remoto con las dos rutinas aportadas; OCR de texto solo no cubre la asociación de colores, tachaduras y escritura. Un servicio mínimo autenticado protege credenciales del proveedor y limita consumo. No incrustar claves de servicio en la app; elegir proveedor y costes con el usuario antes de activar procesamiento pagado.

Enviar solo las imágenes seleccionadas para esa importación, sin añadir historial ni notas ajenas. Evitar logs con imágenes o texto personal; definir retención del proveedor antes de habilitarlo. Errores de red conservan el borrador y permiten reintentar.

Revisión por días con edición de campos y acceso a imagen fuente. Las convenciones del gimnasio, como abdomen sin color a Día 1, son sugerencias marcadas, no certezas. Los pesos los introduce el usuario. Las imágenes son ejemplos de prueba locales; no incorporar información personal a fixtures públicos.

### 7. Localización desde el inicio

String Catalogs para español e inglés, incluidos app, extensiones, mensajes y accesibilidad. Identificadores y reglas independientes del texto localizado; motivos de sugerencias como códigos con parámetros. Usar formatos regionales de número/fecha y parseo compatible con cada locale.

No traducir automáticamente nombres, variantes o notas personalizadas/importadas. Idioma no determina kg/lb. Probar textos largos, Dynamic Type y VoiceOver en ambos idiomas. CSV con identificadores de columna estables documentados, fechas no ambiguas y unidades explícitas, para evitar que cambiar idioma rompa el análisis.

### 8. Instalación y mantenimiento privado

Ad Hoc, una membresía Apple Developer y ambos dispositivos registrados. Compilar con identidad estable y capacidades iCloud/App Groups/extensiones correctas. No se publica en App Store. Documentar instalación desde Mac, fecha de expiración de perfiles, renovación y actualizaciones antes del vencimiento. TestFlight se descarta como vía principal por la expiración de compilaciones a 90 días; la firma gratuita de siete días no sirve para operación diaria.

La cuenta desarrolladora no reemplaza las cuentas personales de iCloud. Validar CloudKit de producción con la compilación distribuida, no solo el entorno de desarrollo.

## Risks / Trade-offs

- Ejecución bloqueada y audio no demostrados → prototipo primero; no prometer paridad basándose en simulador.
- Acciones concurrentes app/extensión → idempotencia, coordinación de escritura y pruebas de doble toque/recuperación.
- Migraciones o restauración destructiva → almacén temporal, validación y copia anterior antes de sustituir.
- Lectura visual incorrecta → revisión obligatoria y campos inciertos explícitos.
- Firma caducada → instrucciones y calendario de renovación; mantener respaldo recuperable.
- Alcance amplio → entregas verticales, todas dentro del alcance inicial; no presentar prototipo como producto terminado.
- Cambiar de gimnasio/rutina con sesión abierta → ofrecer continuar o finalizar la sesión antes de confirmar el cambio, evitando que una sesión pase silenciosamente a otro gimnasio.

## Migration Plan

1. Validar factibilidad bloqueada y persistencia antes de implementar la experiencia completa.
2. Crear proyecto y pruebas del dominio; primera rutina ingresada manualmente, sin migrador Markdown.
3. Al cerrar el grupo 3, seguir la secuencia de entrega por pestaña descrita en Decisions. Incorporar entrenamiento, temporización, superseries, progresión, historial, respaldo e importación a medida que se integren sus flujos.
4. Probar respaldo/restauración y actualización de esquema con datos de ensayo antes de usar datos reales.
5. Registrar ambos iPhone, configurar producción iCloud y distribuir compilación Ad Hoc probada.
6. Antes de cada actualización con cambio de esquema, generar copia recuperable. Un binario anterior no debe abrir un esquema incompatible: restaurar copia compatible si es necesario.

## Open Questions

- Icono y bundle identifier final. Idea inicial para icono el emoji hot face 🥵
- Sonidos concretos diferenciados y textos finales en ambos idiomas.
- Cantidad y frecuencia exactas de copias retenidas, respetando cuota y copia válida anterior.
