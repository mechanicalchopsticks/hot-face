# HotFace
Gym companion app

## Crear la primera rutina con el inventario del gimnasio

Puedes ingresar la rutina directamente en la app, sin preparar ni importar un archivo Markdown.

1. En **Ajustes → Añadir gimnasio**, escribe un nombre y guarda. El primer gimnasio queda activo. Abre su ficha.
2. En **Pesos compartidos** encontrarás tres inventarios iniciales editables: **Tamaños de disco**, **Mancuernas individuales** y **Barras fijas (peso total)**. En **Tamaños de disco → Añadir carga**, agrega un disco de **1,25 lb** y guarda. Conserva los discos iniciales para este ejemplo.
3. En la misma ficha, toca **Añadir equipo**. Crea una **Barra con discos** y una **Máquina de discos**, asigna un nombre a cada una y elige **lb** en ambas. Los dos equipos usan los discos que acabas de editar.
4. En **Rutinas → Añadir rutina**, escribe un nombre. Toca **Añadir día**, nombra el día y usa **Añadir ejercicio** para crear un curl. En **Equipo y carga**, elige la barra. Abre **Carga habitual** y selecciona **6,25 lb** en **Añadido por lado** (un disco de 5 y uno de 1,25 por lado).
5. Vuelve al día y añade un press. Elige la máquina y selecciona **11,25 lb** por lado (10 + 1,25). Vuelve a la rutina y toca **Guardar y activar**.
6. Reabre la rutina desde **Rutinas**. Comprueba que el curl conserva **6,25 lb** por lado y el press **11,25 lb** por lado. Cada ejercicio guarda su propia carga habitual.

## Pruebas

Desde la raíz del repositorio, ejecuta las pruebas de TrainingKit en macOS y el mismo lint que usa CI.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --package-path TrainingKit
git ls-files -z -- '*.swift' | xargs -0 xcrun swift-format lint --strict
```

### Navegación y Dynamic Type

1. Abre `HotFace/HotFace.xcodeproj` en Xcode, selecciona el esquema **HotFace** y elige un simulador de iPhone.
2. Con el tamaño de texto estándar del simulador, selecciona **Spanish** como **App Language** en **Product > Scheme > Edit Scheme > Run > Options**. Ejecuta la app y verifica que abre en **Entrenar**.
3. Toca **Rutinas**, **Historial**, **Ajustes** y vuelve a **Entrenar**. Comprueba que cada pestaña muestra el título correspondiente. En **Ajustes**, comprueba que puedes añadir un gimnasio desde el estado vacío o desde la lista.
4. En Ajustes del simulador, abre **Accesibilidad > Pantalla y tamaño del texto > Texto más grande**, activa los tamaños de accesibilidad y mueve el control al máximo. Repite el recorrido y comprueba que el texto completo se puede leer, desplazándote si hace falta.
5. En Xcode, selecciona **English** y vuelve a ejecutar. Repite el recorrido por **Train**, **Routines**, **History** y **Settings** con el máximo de accesibilidad. Devuelve el texto al tamaño estándar y repite el recorrido.

Para abrir el prototipo de temporizadores, añade `-workout-probe` en **Run > Arguments > Arguments Passed On Launch**. Desactiva ese argumento para volver a probar la navegación.
