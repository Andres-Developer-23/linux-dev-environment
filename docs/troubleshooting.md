# Solución de problemas

Problemas reales que se han encontrado al montar y usar este entorno, con su
diagnóstico y su solución.

---

## El prompt

### Veo cuadritos ▯▯▯ en vez de iconos

**Causa:** la terminal no usa una Nerd Font, que es la que trae los iconos.

**Solución:** en gnome-terminal, `Preferencias → Perfil → Fuente personalizada → MesloLGS
Nerd Font`. El script también puede hacerlo:

```bash
PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'" | awk '{print $NF}')
SCHEMA="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/"
gsettings set "$SCHEMA" use-system-font false
gsettings set "$SCHEMA" font "MesloLGS Nerd Font 12"
gsettings set "$SCHEMA" bold-is-bright true
```

Si el terminal es otro (Kitty, Alacritty, WezTerm), edita su configuración:

```bash
# kitty
echo 'font_family MesloLGS Nerd Font' >> ~/.config/kitty/kitty.conf
# alacritty
echo 'font.family = "MesloLGS Nerd Font"' >> ~/.config/alacritty/alacritty.toml
```

### Los iconos salen como huecos en blanco

**Causa:** el glifo está en el área de uso privado (U+E000–U+F8FF) y se perdió al
escribir o copiar el archivo. Se convierte silenciosamente en un espacio normal: el
prompt sigue funcionando, pero sin iconos.

**Solución:** escríbelos como escapes Unicode de TOML, no como el carácter literal:

```toml
[python]
symbol = "\uE73C"     # en vez del glifo pegado directamente
```

El archivo guarda seis caracteres ASCII y TOML lo convierte al glifo correcto al
leerlo. Explicación completa en
[prompt-starship.md](prompt-starship.md#3-los-iconos-van-como-escapes-uxxxx).

### El módulo de Python aparece siempre en mi carpeta personal

**Causa:** starship activa el módulo si encuentra un `.py` suelto en el directorio
actual. Si tienes un script suelto en `~`, el módulo aparece siempre en casa.

**Solución:** mueve el script a un subdirectorio, o pon `detect_extensions = []` en
`[python]` para que solo se active con `requirements.txt`, `pyproject.toml` o
`setup.py`.

### El prompt no sale en absoluto

```bash
starship --version          # ¿está instalado?
command -v starship         # ¿está en el PATH?
echo $PATH | tr ':' '\n' | grep local
```

Si `~/.local/bin` no está en el PATH, abre una terminal nueva. Si sigue sin estar,
añádelo a `~/.zshenv`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### `starship print-config` avisa de un módulo

```console
[WARN] - (starship::config): Error in 'Go' at 'symbol': Unknown key
```

Significa que el nombre del módulo o de una clave no existe en tu versión de starship.
Los casos más habituales:

| Escribes | Escribe |
|---|---|
| `[go]` | `[golang]` |
| `[csharp]` | `[dotnet]` |
| `[line_number]` | no existe: es un módulo de Neovim |
| `[battery]` con `style` | el estilo va en `[[battery.display]]` |

Lista los módulos de tu versión:

```bash
starship module --list
```

### Falta el `]` en un formato

Los formatos de starship usan grupos de texto `[...]` con estilo `(...)`:

```toml
format = "via [$symbol py $version]($style) "   # correcto
format = "via [$symbol py $version($style) "    # falta el ]
```

Un grupo sin cerrar produce `expected variable, string, textgroup, or conditional`.

### El módulo `custom.ai` sale con un `.ai` pegado

En el formato de primer nivel, los nombres con punto necesitan llaves:

```toml
format = "${custom.ai}"    # correcto
format = "$custom.ai"       # starship lee $custom y deja ".ai" como texto
```

### La batería o la RAM no aparecen

Vienen con umbral: la batería del 10 % (aquí del 30 %) y la RAM del 90 % (aquí del
75 %). Bájalos en `starship.toml`:

```toml
[[battery.display]]
threshold = 50
```

---

## La shell

### `zsh` no es mi shell

```bash
echo $SHELL                              # shell de login
getent passwd "$USER" | cut -d: -f7      # lo mismo, desde /etc/passwd
```

Para cambiarlo:

```bash
sudo chsh -s /usr/bin/zsh "$USER"
```

Cierra sesión y vuelve a entrar. Si no puedes usar `sudo`, `chsh` te pedirá tu
contraseña (no hace falta ser root para cambiar tu propio shell):

```bash
chsh -s /usr/bin/zsh
```

### Los cambios en `~/.zshrc` no se aplican

```bash
source ~/.zshrc     # o el alias: reload
```

Si sigue sin cambiarse, mira si el archivo tiene un error:

```bash
zsh -n ~/.zshrc && echo "sintaxis OK"
```

### `zsh: command not found`

zsh no está instalado. La capa `--apt` lo instala:

```bash
./install.sh --apt
```

### El completado no aparece

```bash
print -l $fpath | grep zsh-completions   # ¿está el path de zsh-completions?
autoload -Uz compinit && compinit         # ¿funciona a mano?
```

Si `compinit` falla con `function definition file not found`, falta la función
`compinit` en el `fpath` — normalmente porque el `fpath` no incluye
`/usr/share/zsh/functions/Completion`.

### fzf no encuentra los widgets

```bash
whence -w fzf-history-widget
```

Si no aparece, `fzf --zsh` no se cargó. Comprueba que `fzf` está instalado y que la
línea `source <(fzf --zsh)` está en el `.zshrc`.

### Los plugins de zsh no cargan

```bash
ls ~/.local/share/zsh-plugins/
zsh -n ~/.zshrc
```

Para reinstalarlos:

```bash
cd ~/dev-setup && ./install.sh --user
```

### El prompt sale pero sin colores

```bash
echo $TERM
echo $COLORTERM
```

`COLORTERM` debería ser `truecolor` (lo pone `~/.zshenv`). Si el `TERM` es `dumb`, la
terminal no soporta secuencias de escape.

---

## El script

### `sudo` pide la contraseña

Es lo esperado, pero solo una vez: `init_sudo` pide `sudo -v` al principio y mantiene
la credencial viva con un proceso en segundo plano. Si el script tarda mucho, el
proceso refresca el timestamp cada 50 segundos.

Si cancelas la autenticación, el script aborta con un mensaje claro en vez de fallar
más tarde con errores confusos.

### `sudo: no hay control de trabajos en este intérprete de órdenes`

Aparece cuando un shell interactivo de bash intenta usar sudo sin terminal
controladora. Es inofensivo, pero si te molesta:

```bash
sudo -v   # valida la credencial una vez
```

### La capa `--apt` se salta paquetes

`apt_install` solo pasa a `apt-get` los que no están instalados. Si un paquete está
en un estado roto (dependencias faltando), dpkg lo cuenta como no instalado y apt lo
reinstala. Para forzar la reparación:

```bash
sudo apt --fix-broken install
```

### `zsh-completions` no está en los repos

No está en Ubuntu 24.04, por eso el script lo clona desde GitHub. Si falla el clone
por red, el resto de la configuración sigue funcionando: solo pierdes los completados
extra.

### La fuente se reinstala en cada ejecución

Síntoma de un bug ya corregido: `grep -q` dentro de un pipeline con `set -o pipefail`
provoca `SIGPIPE` y hace que la comprobación falle siempre.

```bash
# MAL
if fc-list | grep -qi "$label"; then
# BIEN
if fc-list | grep -i "$label" >/dev/null; then
```

Comprueba que tu `install.sh` tiene la versión con la línea `>/dev/null`.

### Un archivo con "no lo sobrescribo"

Los archivos de configuración completa (`~/.tmux.conf`, `~/.config/starship.toml`,
`~/.dircolors`) solo se gestionan si contienen el bloque `dev-setup`. Si los editaste
a mano y quitaste los marcadores, el script deja de tocarlos.

Para recuperarlos:

```bash
cd ~/dev-setup
rm ~/.config/starship.toml        # el backup está en backups/
./install.sh --config
```

O, si quieres conservar tus cambios, borra solo los marcadores… no: lo más simple es
copiar tu versión a un archivo aparte y regenerar.

### `install.sh: línea N: <comando>: not found`

Algún comando no existe en tu sistema. Comprueba con `shellcheck install.sh`:

```bash
sudo apt install shellcheck
shellcheck install.sh
```

### El log de la instalación

Cada ejecución deja su salida completa en `logs/`:

```bash
ls -t ~/dev-setup/logs/ | head
less ~/dev-setup/logs/$(ls -t ~/dev-setup/logs/ | head -1)
```

---

## Docker

### `permission denied` al ejecutar docker

El cambio de grupo necesita una nueva sesión:

```bash
newgrp docker     # solo en esta terminal
# o cierra sesión y vuelve a entrar
docker run --rm hello-world
```

### El repositorio de Docker da error de GPG

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

---

## Bases de datos

### MySQL pide una contraseña y no la recuerdo

Si la instalación se automatizó, la contraseña inicial está en el log de esa
ejecución:

```bash
grep -i "password" ~/dev-setup/logs/*.log | head
```

Si no la encuentras, se puede reestablecer:

```bash
sudo systemctl stop mysql
sudo mysqld_safe --skip-grant-tables &
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'nueva'; FLUSH PRIVILEGES;"
sudo systemctl start mysql
```

### MongoDB no arranca

El repositorio de MongoDB requiere su propia clave GPG y `libssl3`. Comprueba:

```bash
sudo apt install -y gnupg
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
sudo systemctl status mongod
```

---

## Neovim / LazyVim

### LazyVim no termina de instalar los plugins

```bash
nvim
:Lazy
```

La primera instalación descarga todos los plugins y tarda. Si se interrumpe, repite
`:LazyUpdate`.

### `nvim` es el del sistema, no el local

```bash
command -v nvim
nvim --version | head -1
```

El local está en `~/.local/opt/nvim/bin/nvim` y debe ir antes en el PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## Verificación

```bash
cd ~/dev-setup && ./verify.sh
```

Compara el resultado con lo esperado:

| ✗ | Significado | Acción |
|---|---|---|
| `zsh no encontrado` | falta la capa de sistema | `./install.sh --apt` |
| `plugin X ausente` | falta clonar plugins | `./install.sh --user` |
| `starship.toml con errores` | clave o módulo inválido | `starship print-config` para ver el detalle |
| `bloque dev-setup ausente` | el archivo se editó a mano y se perdieron los marcadores | `./install.sh --config` |

---

## Reportar un problema

Si encuentras algo que no funciona, el log de la ejecución y la salida de `verify.sh`
son lo primero que conviene adjuntar.
