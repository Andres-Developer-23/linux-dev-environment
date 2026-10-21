# Android + Flutter (guía manual)

Tu backup pre-reset muestra `.android`, `.gradle`, `.m2`, `.pub-cache` y `.flutter`, así que este stack formaba parte de tu entorno. No está automatizado en `install.sh` porque ocupa **10–15 GB**, requiere GUI y aceptar licencias de Google.

Requisitos previos:

```bash
cd ~/dev-setup
./install.sh --apt --java
```

## 1. Android Studio

Opción Flatpak (ya tienes el remoto `flathub`):

```bash
flatpak install flathub com.google.AndroidStudio
flatpak run com.google.AndroidStudio
```

Opción tarball oficial: descarga Android Studio desde <https://developer.android.com/studio>, descomprime en `~/develop/android-studio` y ejecuta `bin/studio.sh`.

En el asistente inicial, deja el SDK en:

```
~/Android/Sdk
```

## 2. Android SDK por CLI (sin abrir el IDE)

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd /tmp
curl -fLO https://dl.google.com/android/repository/commandlinetools-linux-latest.zip
unzip -q commandlinetools-linux-latest.zip -d cmdline-tools
mv cmdline-tools/cmdline-tools ~/Android/Sdk/cmdline-tools/latest
```

Añade a tu shell. Lo más limpio es el archivo de extensiones personales, que
`dev-setup` carga desde el bloque gestionado de zsh y de bash:

```bash
mkdir -p ~/.config/dev-setup
cat >> ~/.config/dev-setup/local.sh <<'EOF'
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
EOF
```

`~/.config/dev-setup/local.sh` no lo gestiona `dev-setup`: es tuyo, sobrevive a las
ejecuciones del script y es el sitio donde poner todo lo que quieras añadir a tu
entorno.

Instala paquetes (ajusta las versiones a las que liste `sdkmanager --list`):

```bash
sdkmanager --list
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" \
           "emulator" "system-images;android-35;google_apis;x86_64"
yes | sdkmanager --licenses
```

Comprueba:

```bash
adb version
sdkmanager --list_installed
```

## 3. Flutter

```bash
mkdir -p ~/develop
git clone https://github.com/flutter/flutter.git -b stable ~/develop/flutter
```

Añade al shell (mismo archivo de extensiones personales, §2):

```bash
export PATH="$HOME/develop/flutter/bin:$PATH"
```

Configura y valida:

```bash
flutter config --android-sdk "$HOME/Android/Sdk"
flutter doctor --android-licenses
flutter doctor -v
```

## 4. Emulador

```bash
avdmanager create avd -n pixel -k "system-images;android-35;google_apis;x86_64" -d pixel_7
emulator -avd pixel
```

Si el emulador no arranca, comprueba virtualización:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo   # debe ser > 0
sudo apt install cpu-checker && kvm-ok
```

## 5. Proyecto de prueba

```bash
cd ~/develop
flutter create demo
cd demo
flutter run
```

Gradle se usa mediante el wrapper del proyecto (`./gradlew`), no hace falta instalar Gradle global. Maven (`mvn`) ya queda instalado con la capa `--java` para proyectos JVM.

## Notas

- **Java**: Android Studio trae su propio JDK (JBR). Para CLI, OpenJDK 21 funciona con AGP recientes; si un proyecto antiguo pide 17, instala `openjdk-17-jdk` y selecciona con `update-alternatives --config java`.
- **Espacio**: SDK + emulador + Flutter + Gradle pueden superar los 15 GB. Tienes ~151 GB libres.
- **Licencias**: sin `sdkmanager --licenses` / `flutter doctor --android-licenses`, las builds fallan.
- **Variables**: las gestiona `dev-setup` a través de `~/.config/dev-setup/local.sh`, que se carga desde el bloque gestionado de tu shell (zsh y bash). Ese archivo no lo toca el script.
