# El prompt: starship

Guía del prompt que instala `dev-setup`: qué muestra cada módulo, cómo cambiar los
colores y los iconos, y qué tocar para ajustarlo a tu gusto.

El archivo es `~/.config/starship.toml`, escrito dentro del bloque `dev-setup` y
sobrescrito por `./install.sh --config`. Para cambios que sobrevivan a las ejecuciones,
edita la función `starship_block()` en `install.sh`.

---

## 1. Cómo se ve

En un repositorio git con Python y Node:

```
…/api │  main │  9233af2 │ ! │  v3.12.3 │  v24.22.0 │  14:30 ❯
```

En tu carpeta personal:

```
~ │  v3.12.3 │ opencode │  14:30 ❯
```

Tres decisiones de diseño que explican el resultado:

- **El hostname no aparece en local.** Solo se muestra por SSH, donde aporta de verdad.
  En local son 25 caracteres constantes que no cambian nunca.
- **El sistema operativo no aparece.** En Linux siempre diría "Linux".
- **Los iconos sustituyen a las palabras.** Antes ponía `via py v3.12.3`; ahora es un
  icono de Python y la versión. La palabra "via" sobraba.

---

## 2. El separador

Cada módulo termina con un separador tenue:

```toml
format = "[$path]($style) [│](bold #3b4261) "
```

`│` es U+2502 (línea vertical ligera) en `#3b4261`, un gris azulado muy apagado. Separa
los segmentos sin competir con la información.

Como el separador va **dentro** del formato de cada módulo, desaparece cuando ese
módulo no se muestra: si no hay repositorio git, no queda un `│` colgando.

Para cambiar el separador, sustituye `│` en los formatos. Ojos disponibles en la Nerd
Font: `│` (U+2502), `┃` (U+2503), `┆` (U+2506), `╎` (U+254E).

---

## 3. Los iconos van como escapes `\uXXXX`

En el archivo de configuración, los iconos se escriben **como escapes Unicode de
TOML**, no como el carácter literal:

```toml
[python]
symbol = "\uE73C"
```

**Por qué así:** el carácter literal U+E73C está en el área de uso privado. Al copiar,
pegar o pasar el archivo por herramientas que normalizan texto, se convierte
silenciosamente en un espacio normal. Passa desapercibido — el prompt sigue
funcionando, pero los iconos salen como huecos en blanco.

Con el escape `\uE73C`, el archivo contiene seis caracteres ASCII y TOML lo convierte
al glifo correcto al leerlo. Cero posibilidades de corrupción.

Para elegir el glifo de otro módulo, mira los nombres del mapa de la fuente:

```bash
# Ver los glifos de una Nerd Font con su nombre y su codepoint
uv run --with fonttools python -c "
from fontTools.ttLib import TTFont
f = TTFont('$HOME/.local/share/fonts/MesloNerdFont/MesloLGSNerdFont-Regular.ttf')
cmap = f.getBestCmap()
for cp, name in sorted(cmap.items()):
    if cp >= 0xE000 and ('python' in name or 'git_branch' in name or 'clock' in name):
        print(f'U+{cp:04X}  {name}')
"
```

Los que usa esta configuración:

| Glifo | Código | Módulo |
|---|---|---|
| `dev-python` | U+E73C | Python |
| `dev-nodejs_small` | U+E718 | Node.js |
| `dev-bun` | U+E76F | Bun |
| `dev-go` | U+E724 | Go |
| `dev-rust` | U+E7A8 | Rust |
| `dev-java` | U+E738 | Java |
| `dev-kotlin` | U+E81B | Kotlin |
| `dev-ruby` | U+E739 | Ruby |
| `dev-php` | U+E73D | PHP |
| `dev-dotnet` | U+E77F | .NET |
| `dev-swift` | U+E755 | Swift |
| `dev-elixir` | U+E7CD | Elixir |
| `dev-git_branch` | U+E725 | rama de git |
| `dev-git_commit` | U+E729 | hash de commit |
| `seti-docker` | U+E650 | Docker |
| `dev-aws` | U+E7AD | AWS |
| `dev-googlecloud` | U+E7F1 | GCP |
| `cod-clockface` | U+EC75 | reloj |
| `fa-car_battery` | U+EE9E | batería |
| `fa-memory` | U+EFC5 | memoria |

---

## 4. Cómo se compone el prompt

El prompt se define con una cadena `format` en la que cada `$módulo` se inserta en un
punto. El orden de la cadena **es** el orden en pantalla.

```toml
format = """
$os\
$username\
$hostname\
$directory\
$git_branch\
$git_commit\
$git_status\
$python\
$nodejs\
$bun\
$golang\
$rust\
$java\
$kotlin\
$ruby\
$php\
$dotnet\
$swift\
$elixir\
$docker_context\
$container\
$aws\
$gcloud\
$direnv\
${custom.ai}\
$cmd_duration\
$status\
$jobs\
$shlvl\
$battery\
$memory_usage\
$time\
$character"""
```

El `\` al final de cada línea es para que TOML no interprete los saltos de línea: el
prompt se construye en una sola línea lógica.

> **Ojo con los módulos de nombre corto.** En el formato de primer nivel, un nombre con
> punto necesita llaves: `${custom.ai}`, `${env_var.USER}`. Sin las llaves, starship
> interpreta `$custom` y deja el `.ai` como texto literal.

---

## 5. Módulo a módulo

### Sistema operativo y usuario

```toml
[os]
disabled = true

[username]
show_always = false
style_user = "bold #9ece6a"
style_root = "bold #f7768e"
format = "[$user]($style) [│](bold #3b4261) "
```

`os` está desactivado a propósito: en Linux siempre diría "Linux". Para reactivarlo:
`disabled = false` y quita `disabled = true`.

`username` solo aparece si **no** es tu usuario por defecto, y en rojo si eres root.

### Hostname

```toml
[hostname]
ssh_only = true
style = "bold #2ac3de"
format = "[$hostname]($style) [│](bold #3b4261) "
ssh_symbol = "🌐 "
```

Con `ssh_only = true` aparece únicamente cuando estás conectado por SSH. Si prefieres
verlo siempre, ponlo en `false`.

### Directorio

```toml
[directory]
style = "bold #7dcfff"
truncation_length = 3
truncate_to_repo = true
truncation_symbol = "…/"
format = "[$path]($style) [│](bold #3b4261) "
```

`truncation_length = 3` muestra como mucho 3 niveles; `truncate_to_repo = true` corta
en la raíz del repositorio git, para que veas la ruta **dentro** del proyecto y no el
camino completo desde casa.

### Git

```toml
[git_branch]
symbol = "\uE725"
style = "bold #9ece6a"
format = "[$symbol $branch]($style) [│](bold #3b4261) "

[git_commit]
style = "bold #565f89"
format = "[\uE729 $hash]($style) [│](bold #3b4261) "
only_detached = false

[git_status]
style = "#e0af68"
format = "[$all_status$ahead_behind]($style) [│](bold #3b4261) "
stashed = "≡"
untracked = "??"
```

- `git_branch` — la rama actual, en verde, con icono
- `git_commit` — el hash corto, en gris. `only_detached = false` lo muestra siempre; con
  el valor por defecto (`true`) solo aparece cuando el HEAD está desconectado
- `git_status` — los indicadores de cambio:

| Símbolo | Significado |
|---|---|
| `!` | archivos modificados |
| `?` | archivos sin seguimiento |
| `+` / `-` | líneas añadidas / borradas |
| `⇡` / `⇣` | commits por delante / por detrás del remoto |
| `≡` | entradas en el stash |

### Lenguajes

```toml
[python]
symbol = "\uE73C"
style = "bold #e0af68"
format = "[$symbol $version]($style) [│](bold #3b4261) "
```

El mismo patrón para `nodejs`, `bun`, `golang`, `rust`, `java`, `kotlin`, `ruby`,
`php`, `dotnet`, `swift` y `elixir`. Cada uno aparece **solo** si el directorio actual
pertenece a un proyecto de ese lenguaje (detecta `requirements.txt`, `package.json`,
`go.mod`, `Cargo.toml`, `pom.xml`, `mix.exs`…).

> **Nombres exactos:** el módulo de Go es `golang`, no `go`. El de .NET es `dotnet`, no
> `csharp`. `line_number` **no existe** en starship: es un módulo de Neovim/Lua.

> **Nota sobre Python:** starship dispara el módulo si encuentra un `.py` suelto en el
> directorio. Si tienes un script suelto en tu carpeta personal, el módulo Python
> aparecerá siempre en casa. Muévelo a un subdirectorio, o pon
> `detect_extensions = []` en `[python]` para que solo se active con
> `requirements.txt`, `pyproject.toml` o `setup.py`.

### Nube y contenedores

```toml
[docker_context]
symbol = "\uE650"
style = "bold #2ac3de"
format = "[$symbol $context]($style) [│](bold #3b4261) "

[aws]
symbol = "\uE7AD"
style = "bold #ff9e64"
format = "[$symbol $profile]($style) [│](bold #3b4261) "

[gcloud]
symbol = "\uE7F1"
style = "bold #ff9e64"
format = "[$symbol $project]($style) [│](bold #3b4261) "
```

Solo aparecen si hay un contexto activo: un `Dockerfile` o `docker-compose.yml` en el
directorio, o las variables `AWS_PROFILE` / `CLOUDSDK_CORE_PROJECT` definidas.

### direnv

```toml
[direnv]
disabled = false
style = "bold #9ece6a"
format = "[$direnv]($style) [│](bold #3b4261) "
```

`direnv` viene **desactivado** por defecto en starship; hay que poner `disabled = false`
explícitamente. Muestra si el `.envrc` del directorio está cargado y permitido.

### Indicador de opencode

```toml
[custom.ai]
command = "echo ${OPENCODE:+opencode}"
when = "test -n \"$OPENCODE\""
ignore_timeout = true
style = "bold #2ac3de"
format = "[$output]($style) [│](bold #3b4261) "
```

Es un **módulo personalizado**: starship ejecuta el comando y muestra su salida. Aquí
`OPENCODE` es la variable de entorno que opencode exporta en su shell, así que el
prompt se marca cuando estás trabajando dentro de una sesión de opencode.

`ignore_timeout = true` evita que aparezca un aviso si el sistema está cargado y la
comprobación tarda más de lo previsto.

Puedes adaptarlo a cualquier otra herramienta:

```toml
[custom.claude]
command = "echo ${CLAUDECODE:+claude}"
when = "test -n \"$CLAUDECODE\""
```

### Duración, trabajos y nivel

```toml
[cmd_duration]
min_time = 2000
style = "bold #565f89"
format = "[took $duration]($style) [│](bold #3b4261) "

[jobs]
symbol = "\uE7AD"
style = "bold #e0af68"
format = "[$symbol $number_of_jobs]($style) [│](bold #3b4261) "

[shlvl]
style = "bold #565f89"
format = "[$shlvl]($style) [│](bold #3b4261) "
```

- `cmd_duration` — solo si el comando tardó más de 2 segundos (`min_time` en ms)
- `jobs` — el número de trabajos en segundo plano
- `shlvl` — el nivel de anidamiento de shells; `1` es el shell normal, `2` sería uno
  dentro de otro

### Batería y RAM

```toml
[battery]
full_symbol = "\uEE9E"
charging_symbol = "\uEE9E"
discharging_symbol = "\uEE9E"
format = "[$symbol $percentage]($style) [│](bold #3b4261) "

[[battery.display]]
threshold = 30
style = "bold yellow"

[memory_usage]
disabled = false
threshold = 75
style = "bold #9ece6a"
symbol = "\uEFC5"
format = "[$symbol $memory_usage]($style) [│](bold #3b4261) "
```

`battery` viene con un umbral del 10 % por defecto; aquí es del 30 %. El módulo
`battery` **no acepta una clave `style` de primer nivel** — el estilo va en
`[[battery.display]]`. `memory_usage` viene desactivado y con umbral del 75 %.

Los tres estados de batería usan el mismo glifo: el color y el porcentaje ya indican
el estado. Si prefieres un rayo para "cargando", usa `"\uF0E7"` (comprueba antes que
esté en tu fuente).

### Código de salida y hora

```toml
[status]
disabled = false
style = "bold #f7768e"
format = "[✗ $status]($style) [│](bold #3b4261) "

[time]
disabled = false
time_format = "%H:%M"
style = "bold #565f89"
format = "[\uEC75 $time]($style) "
```

`status` muestra el código de salida del último comando **solo si falló**, con una ✗
roja delante. Es informativo sin ruido: si todo va bien, no aparece nada.

La hora es el último módulo, así que no lleva separador.

### El cursor

```toml
[character]
success_symbol = "[❯](bold #9ece6a)"
error_symbol = "[❯](bold #f7768e)"
vicmd_symbol = "[❯](bold #e0af68)"
```

El `❯` es verde si el último comando funcionó y rojo si falló. En vim (normal mode)
cambia a `vicmd_symbol`.

---

## 6. La paleta

El prompt usa una paleta de 256 colores, tema *Tokyo Night*:

| Color | Uso |
|---|---|
| `#7aa2f7` | sistema operativo (desactivado) |
| `#7dcfff` | directorio, fzf |
| `#9ece6a` | rama de git, éxito, batería, RAM |
| `#e0af68` | versiones de lenguaje, estado de git |
| `#f7768e` | errores, código de salida, root |
| `#bb9af7` | Kotlin, Ruby, PHP, Elixir |
| `#2ac3de` | host, Docker, opencode |
| `#565f89` | elementos secundarios: hash, hora, duración |
| `#3b4261` | separadores |
| `#c0caf5` | texto general |

Para cambiar un color, edita el `style` del módulo correspondiente. El formato es el
de starship:

```
bold #7aa2f7        negrita + color
italic              cursiva
dimmed              atenuado
fg:green bg:blue    primer plano / fondo
underline           subrayado
''                  desactiva el estilo
```

---

## 7. Fuente

Los iconos vienen de la **Nerd Font**. Sin ella verás cuadros vacíos.

El script instala dos fuentes y fija la del terminal:

- `MesloLGS Nerd Font` — la que usa el script por defecto
- `JetBrainsMono Nerd Font` — alternativa, algo más compacta

Para cambiarla en gnome-terminal:

```bash
gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'" | awk '{print $NF}')/ font "JetBrainsMono Nerd Font 12"
```

O desde Preferencias → Perfil → Fuente personalizada.

Si prefieres texto plano, quita los `symbol` de los módulos o usa un preset sin Nerd
Font:

```bash
starship preset no-nerd-font > ~/.config/starship.toml
```

---

## 8. Probar sin riesgo

```bash
# Ver cómo quedaría con otro preset
starship preset gruvbox-rainbow | less

# Validar la configuración actual
starship print-config >/dev/null && echo "válida"

# Ver qué muestra cada módulo
starship explain

# Probar un módulo suelto
starship module git_branch

# Ver cuánto tarda cada módulo
starship timings
```

`starship print-config` es la herramienta clave: valida cada clave de cada módulo y
avisa de las que no existen, con un puntero a la línea exacta. Es la forma más rápida
de detectar un error de tipeo.

```console
$ starship print-config
[WARN] - (starship::config): Error in 'Go' at 'symbol': Unknown key
```

---

## 9. Plantillas oficiales

starship trae presets listos que puedes usar como base:

```bash
starship preset --list
```

| Preset | Estilo |
|---|---|
| `gruvbox-rainbow` | arcoíris cálido, muy colorido |
| `tokyo-night` | el que usa este proyecto, en versión completa |
| `bracketed-segments` | segmentos entre corchetes, muy legible |
| `catppuccin-powerline` | powerline con colores pastel |
| `pure-preset` | minimalista, dos colores |
| `plain-text-symbols` | sin iconos |
| `no-nerd-font` | para terminales sin Nerd Font |
| `no-runtime-versions` | sin versiones de lenguajes |

```bash
starship preset gruvbox-rainbow > ~/.config/starship.toml
```

Para aplicarlos de forma permanente, edita `starship_block()` en `install.sh`.

---

## 10. Problemas frecuentes

**"Cuadritos en vez de iconos"**
→ falta la Nerd Font en el perfil del terminal. Ver [§7](#7-fuente).

**"Los iconos salen como huecos en blanco"**
→ el glifo se perdió al escribir el archivo. Usa escapes `\uXXXX` en vez del carácter
literal. Ver [§3](#3-los-iconos-van-como-escapes-uxxxx).

**"No aparece el módulo de Go"**
→ el módulo se llama `golang`. Y solo aparece en directorios con `go.mod`.

**"La batería no sale"**
→ el umbral es del 30 %. Si la batería está por encima, no se muestra. Bájalo en
`[[battery.display]] threshold`.

**"El indicador de opencode no aparece"**
→ el módulo solo se activa si la variable `OPENCODE` está exportada. Comprueba con
`echo $OPENCODE`.

**"starship no se actualiza tras editar el TOML"**
→ `starship` relee el archivo en cada prompt; si no ves los cambios, quizá hay un error
de sintaxis. Valida con `starship print-config`.

**"El prompt va lento"**
→ `command_timeout = 2000` limita a 2 segundos el trabajo de los módulos. Si tienes
muchos repos git abiertos, baja ese valor o quítalo.
