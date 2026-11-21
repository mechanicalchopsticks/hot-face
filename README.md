# HotFace
Gym companion app

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
