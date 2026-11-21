## Purpose

Permitir que cada persona use la interfaz en el idioma de su iPhone, manteniendo intactos sus datos y las unidades elegidas para entrenar.

## ADDED Requirements

### Requirement: Español e inglés
La app SHALL ofrecer su interfaz en español e inglés y seleccionar el idioma según la configuración de idioma aplicable del iPhone. SHALL localizar navegación, acciones, errores, sugerencias, accesibilidad, notificaciones y controles de pantalla bloqueada.

#### Scenario: Dispositivos con idiomas distintos
- **WHEN** un usuario abre la app en español y su esposa la abre en un iPhone configurado en inglés
- **THEN** cada uno recibe la interfaz en su idioma, incluyendo Fácil/Easy y Difícil/Hard

### Requirement: Datos y formatos independientes del idioma
La app SHALL preservar los nombres y notas introducidos o importados sin traducirlos automáticamente. Los números y fechas SHALL presentarse según la configuración regional, sin cambiar la unidad de carga elegida ni el valor almacenado.

#### Scenario: Carga decimal
- **WHEN** se muestra una carga de 12,5 kg en la interfaz inglesa con formato decimal de punto
- **THEN** muestra 12.5 kg sin convertirla a lb ni modificar el saldo

#### Scenario: Rutina con texto personalizado
- **WHEN** cambia el idioma de la interfaz
- **THEN** conserva literalmente los nombres de ejercicios, variantes y notas del usuario
