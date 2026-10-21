# El prompt: starship

Guía del prompt que instala `dev-setup`: qué muestra cada módulo, cómo cambiar los
colores y los iconos, y qué tocar para ajustarlo a tu gusto.

El archivo es `~/.config/starship.toml`, escrito dentro del bloque `dev-setup` y
sobrescrito por `./install.sh --config`. Para cambios que sobrevivan a las ejecuciones,
edita la función `starship_block()` en `install.sh`.

---

## 1. Cómo se compone el prompt

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

## 2. Módulo a módulo

### Sistema operativo y usuario

```toml
[os]
style = "bold #7aa2f7"
format = "[ $os ]"

[username]
show_always = false
style_user = "bold #9ece6a"
style_root = "bold #f7768e"
format = " [$user]($style)"
```

`os` muestra «Linux». `username` solo aparece si **no** es tu usuario por defecto, y en
rojo si eres root.

### Hostname

```toml
[hostname]
ssh_only = false
style = "bold #2ac3de"
format = "[$hostname]($style) "
ssh_symbol = "🌐 "
```

Con `ssh_only = false` aparece siempre. Si lo pones en `true`, solo cuando estés
conectado por SSH, que es lo habitual.

### Directorio

```toml
[directory]
style = "bold #7dcfff"
truncation_length = 3
truncate_to_repo = true
truncation_symbol = "…/"
format = "[$path]($style) "
```

`truncation_length = 3` muestra como mucho 3 niveles; `truncate_to_repo = true` corta
en la raíz del repositorio git, para que veas la ruta **dentro** del proyecto y no el
camino completo desde casa.

### Git

```toml
[git_branch]
symbol = " "
style = "bold #9ece6a"
format = "on [$symbol$branch]($style) "

[git_commit]
style = "bold #565f89"
format = "([$hash]($style))"
only_detached = false

[git_status]
style = "#e0af68"
format = "([$all_status$ahead_behind]($style) )"
stashed = "≡"
untracked = "??"
```

- `git_branch` — la rama actual, en verde
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
symbol = " "
style = "bold #e0af68"
format = "via [$symbol py $version]($style) "
```

El mismo patrón para `nodejs`, `bun`, `golang`, `rust`, `java`, `kotlin`, `ruby`,
`php`, `dotnet`, `swift` y `elixir`. Cada uno aparece **solo** si el directorio actual
pertenece a un proyecto de ese lenguaje (detecta `requirements.txt`, `package.json`,
`go.mod`, `Cargo.toml`, `pom.xml`, `mix.exs`…).

> **Nombres exactos:** el módulo de Go es `golang`, no `go`. El de .NET es `dotnet`, no
> `csharp`. `line_number` **no existe** en starship: es un módulo de Neovim/Lua.

### Nube y contenedores

```toml
[docker_context]
symbol = " "
style = "bold #2ac3de"
format = "via [$symbol ctx.$context]($style) "

[aws]
symbol = " "
style = "bold #ff9e64"
format = "via [$symbol aws.$profile]($style) "

[gcloud]
symbol = " "
style = "bold #ff9e64"
format = "via [$symbol gcloud.$project]($style) "
```

Solo aparecen si hay un contexto activo: un `Dockerfile` o `docker-compose.yml` en el
directorio, o las variables `AWS_PROFILE` / `CLOUDSDK_CORE_PROJECT` definidas.

### direnv

```toml
[direnv]
disabled = false
style = "bold #9ece6a"
format = "[$direnv]($style) "
```

`direnv` viene **desactivado** por defecto en starship; hay que poner `disabled = false`
explícitamente. Muestra si el `.envrc` del directorio está cargado y permitido.

### Indicador de opencode

```toml
[custom.ai]
command = "echo ${OPENCODE:+opencode}"
when = "test -n \"$OPENCODE\""
style = "bold #2ac3de"
format = "[$output]($style) "
```

Es un **módulo personalizado**: starship ejecuta el comando y muestra su salida. Aquí
`OPENCODE` es la variable de entorno que opencode exporta en su shell, así que el
prompt se marca cuando estás trabajando dentro de una sesión de opencode.

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
format = "[took $duration]($style) "

[jobs]
symbol = " "
style = "bold #e0af68"
format = "[$symbol $number_of_jobs]($style) "

[shlvl]
style = "bold #565f89"
format = "[$shlvl]($style) "
```

- `cmd_duration` — solo si el comando tardó más de 2 segundos (`min_time` en ms)
- `jobs` — el número de trabajos en segundo plano
- `shlvl` — el nivel de anidamiento de shells; `1` es el shell normal, `2` sería uno
  dentro de otro

### Batería y RAM

```toml
[battery]
full_symbol = " "
charging_symbol = " "
discharging_symbol = " "
format = "[$symbol $percentage]($style) "

[[battery.display]]
threshold = 30
style = "bold yellow"

[memory_usage]
disabled = false
threshold = 75
style = "bold #9ece6a"
format = "[$symbol $memory_usage]($style) "
```

`battery` viene con un umbral del 10 % por defecto; aquí es del 30 %. El módulo
`battery` **no acepta una clave `style` de primer nivel** — el estilo va en
`[[battery.display]]`. `memory_usage` viene desactivado y con umbral del 75 %.

### Código de salida y hora

```toml
[status]
disabled = false
style = "bold #f7768e"
format = "[$status]($style)"

[time]
disabled = false
time_format = "%H:%M"
style = "bold #565f89"
format = "([$time]($style) )"
```

`status` muestra el código de salida del último comando **solo si falló**. Es
informativo sin ruido: si todo va bien, no aparece nada.

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

## 3. La paleta

El prompt usa una paleta de 256 colores, tema *Tokyo Night*:

| Color | Uso |
|---|---|
| `#7aa2f7` | sistema operativo, directorio |
| `#7dcfff` | directorio, fzf |
| `#9ece6a` | rama de git, éxito, batería |
| `#e0af68` | versiones de lenguaje, estado de git |
| `#f7768e` | errores, código de salida, root |
| `#bb9af7` | Kotlin, Ruby, PHP |
| `#2ac3de` | host, Docker, opencode |
| `#565f89` | elementos secundarios: hash, hora, duración |
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

## 4. Iconos

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

## 5. Probar sin riesgo

```bash
# Ver cómo quedaría con otro preset
starship preset gruvbox-rainbow | less

# Validar la configuración actual
starship print-config >/dev/null && echo "válida"

# Ver qué muestra cada módulo
starship explain

# Probar un módulo suelto
starship module git_branch
```

`starship print-config` es la herramienta clave: valida cada clave de cada módulo y
avisa de las que no existen, con un puntero a la línea exacta. Es la forma más rápida
de detectar un error de tipeo.

```console
$ starship print-config
[WARN] - (starship::config): Error in 'Go' at 'symbol': Unknown key
```

---

## 6. Plantillas oficiales

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

## 7. Problemas frecuentes

**"Cuadritos en vez de iconos"**
→ falta la Nerd Font en el perfil del terminal. Ver [§4](#4-iconos).

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
→ `command_timeout = 1000` limita a 1 segundo el trabajo de los módulos. Si tienes
muchos repos git abiertos, baja ese valor o quitalo.
