# Tasks

## 1. Factibilidad en iPhone

- [x] 1.1 Inspeccionar Xcode/SDK y versiones de ambos dispositivos; entregar registro de compatibilidad con iOS 26 y lista concreta de requisitos de firma.
- [x] 1.2 Crear un proyecto mínimo de prueba con app y extensión de Live Activity; verificar compilación e inicio en simulador sin incluir todavía datos reales.
- [x] 1.3 Probar AlarmKit, ActivityKit y App Intents en iPhone para completar serie, iniciar/pausar/reanudar, tres segundos preparatorios y transición automática a descanso; documentar resultados observables y permisos.
- [x] 1.4 Probar señales diferenciadas, sostenimientos, música y audífonos con pantalla bloqueada/cambio de app; entregar matriz de resultados que distinga cierre forzado y reinicio de bloqueo normal.
- [x] 1.5 Validar SwiftData y almacenamiento compartido app/extensión con dos acciones concurrentes y recuperación; demostrar que no se pierde ni duplica una serie.
- [x] 1.6 Consolidar el resultado de factibilidad contra workout-timers; si algún requisito no es viable, presentar evidencia y resolver con el usuario antes de implementar esa parte.

## 2. Base de la aplicación y datos

- [x] 2.1 Crear módulos de dominio, repositorios, adaptadores e interfaz, con reloj inyectable; verificar build y una prueba de transición sin interfaz.
- [x] 2.2 Definir entidades versionadas e instantáneas de sesión; verificar guardado/recarga y que editar una rutina no modifica una sesión histórica.
- [x] 2.3 Implementar comandos persistentes e idempotentes de sesión; probar doble toque y recuperación después de cada transición crítica.
- [x] 2.4 Incorporar String Catalogs español/inglés en app y extensiones; verificar selección por idioma y formatos decimales/fechas sin cambiar kg/lb ni textos personalizados.
- [x] 2.5 Crear navegación Entrenar/Rutinas/Historial/Ajustes y estados vacíos; recorrerla en ambos idiomas con Dynamic Type y documentar cómo ejecutar las pruebas.

## 3. Gimnasios, equipos y primera rutina

Continuación de 3.1: comenzar por 3.11 (modelo y migración) y 3.12 (Ajustes). Usar el catálogo resultante en 3.2 y 3.3 antes de integrar el selector en 3.5.

- [x] 3.1 Implementar perfiles de gimnasio y equipo con cargas disponibles; verificar creación/edición y selección independiente por gimnasio.
- [ ] 3.2 Implementar la selección de mancuernas individuales y barras fijas del gimnasio, y los 30 valores de máquinas selectoras de paso de 5 kg (5–150 kg). Probar 10 lb y 10 kg en el mismo inventario, una y dos mancuernas, peso total de barra fija y conversiones de ida y vuelta por unidad/total/por lado que conserven carga física y saldo.
- [ ] 3.3 Calcular las cargas simétricas alcanzables con los tamaños de disco compartidos y repetibles. Probar 30 frente a 31 lb añadidas, retirar tamaños pequeños, admitir 500 y descartar 505 lb, y aplicar un máximo inferior por lado específico de una máquina. Excluir el peso propio de los límites y del porcentaje de progresión.
- [ ] 3.4 Implementar estados de carga sin definir/estimada/confirmada; verificar que usar una estimación no la confirma y que cero no equivale a ausente.
- [ ] 3.5 Crear el editor manual de rutinas, días, ejercicios, variantes, segmentos y descansos con el selector de carga según gimnasio y equipo. Ingresar una rutina con tiempo, repeticiones por lado y 7+7+7. Verificar que dos ejercicios consultan el mismo inventario y guardan cargas habituales independientes.
- [ ] 3.6 Implementar activación, copia y archivo; probar cambio y regreso de gimnasio con rutina nueva, saldos cero e historial anterior conservado.
- [ ] 3.7 Implementar ciclos y orden temporal/habitual de días; probar omisiones, fechas distintas, cierre de ciclo y disponibilidad en el siguiente.
- [ ] 3.8 Documentar y verificar el flujo desde los inventarios iniciales editables del gimnasio hasta la elección de carga por ejercicio en la primera rutina, sin importar Markdown.
- [ ] 3.9 Consultar localmente la última carga real por gimnasio y nombre. Probar con varias rutinas archivadas, una sesión parcial, una omisión posterior, una carga cero y un registro más reciente de otro gimnasio.
- [ ] 3.10 Integrar la sugerencia en el editor de rutinas nuevas. Verificar la comparación de 4 × (7+7+7) frente a 3 × 8, fecha, carga, unidad, estación e indicaciones disponibles, sin mostrar el gimnasio. Probar confirmar, editar, dejar sin definir y conservar una carga copiada.
- [x] 3.11 Persistir los tres inventarios compartidos por gimnasio, con unidad por entrada y valores iniciales de gym-equipment. Migrar catálogos de 3.1. Reabrir un almacén congelado de V3 con dos equipos que comparten tamaños y comprobar deduplicación, unidades, pesos propios, selección de gimnasio e historial. Conservar las fixtures anteriores.
- [x] 3.12 Adaptar Ajustes para editar los tres inventarios una vez por gimnasio, el peso propio de la barra (45 lb iniciales) y el máximo opcional por lado de barras y máquinas de discos. Verificar en español e inglés la edición de unidades mixtas, que los pesos retirados siguen ausentes al reabrir y que otro gimnasio conserva sus valores.

## 4. Entrenamiento básico de principio a fin

- [ ] 4.1 Implementar pantalla de serie con nombre, estación, equipo e indicaciones; verificar que Completar registra valores e inicia descanso con un toque.
- [ ] 4.2 Implementar corrección de serie durante descanso y series que incluyen ambos lados; probar que corregir no duplica series ni altera la rutina habitual.
- [ ] 4.3 Implementar cambios temporales, reutilización de ajustes y guardado explícito habitual; verificar persistencia solo en el ámbito elegido.
- [ ] 4.4 Implementar añadir, sustituir, posponer, seleccionar y omitir ejercicios; probar estación ocupada, regreso y conservación del orden habitual.
- [ ] 4.5 Implementar cierre completo/parcial y resumen; verificar conservación de series/valoraciones, pendientes no realizados, día completado y ausencia de descanso final.
- [ ] 4.6 Implementar recuperación de sesión abierta; probar cierre inesperado y reapertura en otra fecha con opciones continuar/finalizar.
- [ ] 4.7 Completar un ciclo sin conexión y revisar historial; entregar prueba integrada y guía breve de sesión parcial frente a sesión abierta.

## 5. Temporizadores, audio y superseries

- [ ] 5.1 Integrar la solución validada de temporización con estados persistidos y reloj inyectable; probar pausas, tres segundos preparatorios, fin anticipado y tiempo restante.
- [ ] 5.2 Implementar descansos 1:45/2:15 y ajustes por rutina/ejercicio/superserie, ±15 s y terminar; probar que no cambian valores futuros ni producen tiempos negativos.
- [ ] 5.3 Implementar transiciones a siguiente serie/ejercicio en espera; verificar vencimiento fuera de app y ausencia de arranque automático no solicitado.
- [ ] 5.4 Implementar temporización por lado, sostenimientos y reinicio configurable; probar señal/transición del primer lado y descanso solo tras ambos.
- [ ] 5.5 Implementar creación y desarme de superseries habituales/temporales; probar rondas, series iguales, prescripciones mixtas y conservación del progreso al desarmar.
- [ ] 5.6 Integrar controles bloqueados y señales localizadas; verificar una sesión real con música/audífonos y permisos concedidos/denegados sin presentar controles inoperantes como exitosos.
- [ ] 5.7 Documentar capacidades comprobadas, límites del sistema y pasos de permisos; contrastar la guía con la matriz de dispositivos.

## 6. Progresión y valoración

- [ ] 6.1 Implementar saldo saturado y valoración opcional de ejercicios completos/parciales; probar cancelación, límites, ausencia de valoración y ajustes temporales.
- [ ] 6.2 Implementar reinicios por cambios habituales y sustituciones; verificar que notas, orden y representación de carga no reinician.
- [ ] 6.3 Implementar sugerencias de peso desde las mismas cargas disponibles que ofrece el editor según el gimnasio y el equipo. Probar el umbral inclusivo del 10 %, carga cero, inventario limitado y 50→52,5 y 50→55 conservando repeticiones. Verificar que el motor descarta cargas de discos inalcanzables o superiores al límite del equipo.
- [ ] 6.4 Implementar puente de repeticiones separado del saldo; probar 35×10→35×12→45×10 y retorno a 12 tras puente a 15.
- [ ] 6.5 Implementar escalones de subida/bajada, caso 15 sin puente y límites sin carga mayor/menor; probar 9→10/8, mínimo 6 y ajuste manual en tiempo/combinados.
- [ ] 6.6 Revisar con el usuario la política propuesta de invalidación del puente al editar una sugerencia; documentar la decisión y cubrirla con pruebas antes de codificar ese caso.
- [ ] 6.7 Integrar sugerencia editable al iniciar y confirmación habitual; probar rechazo repetido, aceptación personalizada, reinicio del saldo y motivo en ambos idiomas.

## 7. Historial, notas y CSV

- [ ] 7.1 Implementar consultas de sesiones, progreso y marcas con unidades explícitas; verificar sesiones parciales y comparación sin confundir equipos o gimnasios.
- [ ] 7.2 Registrar cambios habituales con fecha y valores anteriores/nuevos; probar sugerencia editada, sustitución y archivo sin reescribir el pasado.
- [ ] 7.3 Implementar notas fechadas con editar/eliminar/deshacer/rehacer; verificar el alcance de deshacer durante la edición.
- [ ] 7.4 Implementar exportación CSV de entrenamientos y cambios; probar caracteres especiales, texto multilínea, unidades mixtas, cero/ausente y relaciones entre filas.
- [ ] 7.5 Documentar columnas y formatos CSV y verificar que una exportación de muestra se interpreta igual desde interfaces española e inglesa.

## 8. Respaldo y restauración privados

- [ ] 8.1 Configurar capacidades y contenedor privado CloudKit al disponer de membresía; verificar acceso separado con ambas cuentas de prueba.
- [ ] 8.2 Implementar snapshot consistente versionado, subida de assets y manifiesto final; probar interrupción de red sin publicar una copia incompleta.
- [ ] 8.3 Implementar reintento automático y estado de último respaldo; probar cuenta ausente, cuota, offline y retorno de conectividad sin bloquear sesiones.
- [ ] 8.4 Implementar restauración a almacén temporal y sustitución validada; probar copia corrupta, esquema anterior y preservación de datos locales si falla.
- [ ] 8.5 Definir y documentar retención y cambio de cuenta; verificar aislamiento entre usuarios y que siempre se conserva una copia válida durante renovación.

## 9. Importación y revisión de fotografías

- [ ] 9.1 Definir contrato estructurado de extracción y borrador revisable; validar ejemplos sintéticos de ambas caras, campos dudosos y repetición combinada.
- [ ] 9.2 Evaluar proveedor visual, coste y tratamiento de imágenes; entregar comparación y elección antes de activar servicios pagados.
- [ ] 9.3 Implementar servicio mínimo autenticado y adaptador, sin claves en el cliente ni imágenes en logs; probar peticiones inválidas, límites, timeout y reintento.
- [ ] 9.4 Evaluar extracción con rutina1 y rutina3 como muestras locales autorizadas; verificar leyendas diferentes, numeración, estación tachada, escritos sin color y MAQ distinto de carga.
- [ ] 9.5 Implementar revisión editable por días con referencia a imagen; verificar corrección de orden, nombres, tiempos, c/u y segmentos antes de guardar.
- [ ] 9.6 Implementar convención configurable del gimnasio para abdomen sin día a Día 1 por confirmar; probar prioridad de día explícito y ausencia de esa convención en otros gimnasios.
- [ ] 9.7 Integrar el borrador importado con el editor de rutina y las superseries manuales. Verificar que una carga ausente de la hoja solo se completa por entrada del usuario o confirmación de la sugerencia histórica. Completar importación→edición→entrenamiento sin red y documentar qué debe revisarse.

## 10. Distribución y comprobación integrada

- [ ] 10.1 Preparar firma Ad Hoc, registrar ambos dispositivos y documentar expiración/renovación; verificar instalación privada con identidad estable.
- [ ] 10.2 Validar iCloud de producción en la compilación distribuida; restaurar datos de ensayo de cada cuenta sin intercambio de información.
- [ ] 10.3 Ejecutar en ambos iPhone el flujo crear/importar→entrenar parcial→recuperar→finalizar→progresar→respaldar→exportar, en español e inglés; registrar evidencias y fallos.
- [ ] 10.4 Probar actualización sobre instalación previa con datos de ensayo y migración de esquema; verificar conservación del historial y procedimiento documentado de recuperación.
- [ ] 10.5 Revisar todos los escenarios de las ocho especificaciones y la matriz de audio/bloqueo; entregar informe con resultados reales y limitaciones pendientes, sin marcar como probado lo evaluado solo en simulador.
