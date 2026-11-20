---
sidebar_position: 0
---

# 🐕 Guía Fácil Paso a Paso (Para Todos los Niveles)

¡Bienvenido/a a **Golden Dog Linux**! Si acabas de instalar el sistema o no tienes mucha experiencia con la terminal de Linux, esta guía está pensada especialmente para ti.

Aquí aprenderás **qué hace este proyecto**, **cómo poner tu ordenador a punto con un solo comando** y **cómo usar sus herramientas en tu día a día** sin complicaciones técnicas.

---

## 1. ¿Qué es este proyecto y para qué sirve?

**Golden Dog Linux** es un sistema rápido, moderno y limpio basado en **Debian 13** con el escritorio **KDE Plasma**. Cuando instalas un sistema desde cero, normalmente tienes que dedicar horas a instalar programas, configurar códecs de vídeo, ajustar el rendimiento o preparar tus herramientas de trabajo.

Este proyecto es un **"asistente automático"** que hace todo ese trabajo por ti en pocos minutos:

* 🎨 **Respeta el diseño original al 100%**: No cambia tu fondo de pantalla, ni tus colores, ni los iconos ni los paneles que trae Golden Dog Linux. Solo añade mejoras prácticas por debajo.
* 🎬 **Multimedia lista para usar**: Instala todos los códecs para que puedas ver cualquier vídeo, escuchar cualquier formato de música y ver las miniaturas de tus vídeos en el gestor de archivos (**Dolphin**).
* 🚀 **Ordenador más rápido**: Configura memoria comprimida ultrarrápida (**ZRAM**) para que el sistema nunca se bloquee aunque abras muchas pestañas o programas pesados.
* 🛡️ **Seguro desde el primer minuto**: Configura el cortafuegos (**UFW**) para proteger tu equipo en red sin impedir que uses tu móvil (**KDE Connect**) o el panel de control web (**Cockpit**).
* 📦 **Tienda de aplicaciones lista**: Conecta el centro de software (**KDE Discover**) con **Flathub** para que puedas instalar aplicaciones como VLC, Spotify, LibreOffice, Telegram o Discord a golpe de clic.

> [!NOTE]
> **¿Con qué ordenadores es compatible?**
> Funciona en cualquier ordenador de sobremesa o portátil con procesador y gráficos **AMD** o **Intel**. *(Nota: Las tarjetas gráficas dedicadas Nvidia no están incluidas en estos scripts).*

---

## 2. Antes de empezar: ¿Cómo abro la terminal y preparo todo?

Solo necesitas copiar y pegar **3 comandos** para descargar este asistente en tu ordenador.

1. Abre tu **Terminal** (puedes buscar *"Konsole"* en el menú de inicio de abajo a la izquierda).
2. Copia y pega el siguiente bloque para instalar las dos herramientas básicas (`git` para descargar el proyecto y `just` para ejecutar los comandos fáciles):

```bash
sudo apt update && sudo apt install -y git just
```
*(Te pedirá tu contraseña de usuario. Al escribirla no se verán asteriscos por seguridad; escríbela normal y pulsa `Enter`).*

3. Descarga este proyecto y entra en su carpeta:

```bash
mkdir -p ~/Workspace/Repositorios
cd ~/Workspace/Repositorios
git clone https://github.com/GoldendogLinux/GoldenDogLinux.git
cd GoldenDogLinux
```
*(Si ya tienes la carpeta descargada en tu ordenador, simplemente entra en ella con `cd ~/Workspace/Repositorios/GoldenDogLinux`).*

---

## 3. La Forma Fácil: Configurar todo con un solo comando

El proyecto utiliza una herramienta llamada **`just`**. Piensa en `just` como un menú de botones rápidos: en lugar de recordar comandos largos, solo escribes `just` seguido de lo que quieres hacer.

### Opción A: "¡Hazlo todo por mí!" (Recomendado)

Si quieres dejar el ordenador completamente configurado (drivers AMD/Intel, códecs de vídeo, navegador Chrome, terminal mejorada, fuentes, seguridad y herramientas), escribe:

```bash
just setup-all
```

El asistente detectará automáticamente si tu procesador es **AMD** o **Intel** y configurará todo paso a paso (sistema base, multimedia, Flatpak, Chrome, rendimiento, KDE, terminal, seguridad, fuentes, Fastfetch, Kitty, IDEs, Git, lenguajes y Podman). Cuando termine, **reinicia tu ordenador** y estará listo.

*(Nota: Herramientas opcionales como `firefox`, `zsh`, `starship`, `cockpit`, `yt-dlp`, `virtualization` o `kodi` no están en `setup-all` y puedes instalarlas aparte si las quieres.)*

---

### Opción B: Elegir solo lo que necesitas (A la carta)

Si no eres programador o prefieres instalar solo algunas cosas concretas, puedes ejecutar únicamente las piezas que te interesen:

| ¿Qué quieres hacer? | Comando que debes escribir | ¿Qué hace exactamente en lenguaje sencillo? |
| :--- | :--- | :--- |
| **1. Puesta a punto básica y drivers** | `just post-install` | Actualiza el sistema, instala los drivers de tu procesador/gráfica (AMD o Intel), activa el sonido PipeWire y la memoria rápida ZRAM. |
| **2. Ver cualquier vídeo y música** | `just multimedia` | Instala todos los códecs (MP4, MKV, MP3, FLAC...), activa la aceleración de vídeo y las vistas previas en tus carpetas. |
| **3. Mejorar el gestor de archivos** | `just kde-setup` | Configura Dolphin con vista de detalles, miniaturas de vídeo y activa el atajo `Ctrl + Alt + T` para abrir la terminal. **No cambia tu tema visual**. |
| **4. Acelerar el sistema** | `just tuning` | Ajusta el motor interno de Linux para que vaya más fluido, apague rápido y aproveche mejor tu disco SSD y memoria RAM. |
| **5. Activar el cortafuegos** | `just security` | Configura el cortafuegos **UFW** para proteger tu PC permitiendo usar KDE Connect y la consola web Cockpit. |
| **6. Instalar Google Chrome** | `just chrome` | Instala el navegador Google Chrome oficial optimizado para que los vídeos de YouTube gasten menos batería. |
| **7. Instalar Mozilla Firefox** | `just firefox` | Instala la versión oficial más reciente de Firefox en español. |
| **8. Instalar aplicaciones (Flatpak)** | `just flatpak` | Activa el catálogo Flathub e instala herramientas esenciales para gestionar tus aplicaciones (**Flatseal** y **Warehouse**). |
| **9. Terminal moderna (Kitty)** | `just kitty` | Instala la terminal **Kitty** con efecto cristal desenfocado y colores oscuros agradables a la vista. |

---

## 4. Cómo instalar tus programas favoritos (VLC, Spotify, LibreOffice, etc.)

Una vez ejecutado `just flatpak` (o `just multimedia`), tienes dos formas muy sencillas de instalar programas para tu día a día:

### Forma 1: Con el ratón desde la tienda visual (KDE Discover)
1. Abre el menú de aplicaciones de KDE y busca **Discover** (el centro de software).
2. Busca cualquier aplicación (por ejemplo: *Telegram*, *VLC*, *Spotify*, *LibreOffice*, *OBS Studio*, *Kdenlive*) y pulsa **Instalar**.

### Forma 2: Desde la terminal por categorías o nombre
El script de Flatpak incluye atajos para instalar paquetes de aplicaciones de una sola vez:

```bash
# Instalar una aplicación concreta por su nombre:
./Setup/flatpak.sh install vlc
./Setup/flatpak.sh install spotify
./Setup/flatpak.sh install libreoffice
./Setup/flatpak.sh install telegram
./Setup/flatpak.sh install discord
./Setup/flatpak.sh install obsidian

# O instalar grupos enteros de aplicaciones:
./Setup/flatpak.sh --multimedia     # Instala VLC, OBS Studio, Kdenlive, Spotify, Kodi, etc.
./Setup/flatpak.sh --productivity   # Instala LibreOffice, Obsidian, LocalSend y Pika Backup
./Setup/flatpak.sh --comms          # Instala Discord (Vesktop) y Telegram
./Setup/flatpak.sh --graphics       # Instala GIMP e Inkscape
```

---

## 5. Cómo comprobar que todo funciona bien (Diagnóstico sin miedo)

Todos los módulos tienen un **modo diagnóstico** (`status`). Estos comandos **solo leen información** (no modifican ni rompen nada) y te muestran con iconos verdes (`✅`) si todo está bien:

```bash
just status              # Resumen general del rendimiento, seguridad, KDE y Cockpit
just multimedia-status   # Comprueba si los códecs y tu tarjeta gráfica están acelerando vídeo
just security-status     # Muestra si el cortafuegos UFW está activo y protegiendo el equipo
just cockpit-status      # Comprueba el panel de control web Cockpit
just flatpak-status      # Muestra qué aplicaciones Flatpak tienes instaladas
```

---

## 6. Trucos y Atajos Útiles para tu Día a Día

### ⌨️ En el Escritorio KDE Plasma (con `just kde-setup` / `just kitty`)
* **`Ctrl + Alt + T`**: Abre la terminal instantáneamente desde cualquier lugar.
* **Clic derecho en cualquier carpeta (Dolphin)**: Verás nuevas opciones como **"Abrir en Kitty"** o **"Abrir con Antigravity"** para abrir la terminal o tu editor directamente en esa carpeta.

### 🌐 Panel de Control Web (Cockpit)
Golden Dog Linux incluye **Cockpit**, un panel visual que puedes abrir en tu navegador web para ver gráficos de memoria, discos, actualizaciones, contenedores y máquinas virtuales:
* Escribe `just cockpit-open` en la terminal, o abre tu navegador y entra en: **`https://localhost:9090`**
* Inicia sesión con el **mismo nombre de usuario y contraseña** que usas para entrar en tu ordenador. *(Nota: Si el navegador te avisa de que el certificado es autofirmado, pulsa en "Configuración avanzada" -> "Acceder a localhost", es normal porque es tu propio ordenador).*

### 🐚 Atajos fáciles en la Terminal (con `just shell`)
Cuando abras la terminal, puedes escribir estas palabras cortas:

| Atajo | ¿Qué hace? |
| :--- | :--- |
| `ff` o `sysinfo` | Muestra un resumen visual precioso con la información de tu ordenador (Fastfetch). |
| `upgrade` | Actualiza todos los paquetes del sistema Debian (`sudo apt update && sudo apt upgrade -y`). |
| `clean` | Limpia paquetes antiguos que ya no sirven para liberar espacio en disco. |
| `ll` o `la` | Muestra los archivos de la carpeta actual con iconos, colores y detalles. |
| `..` / `...` | Sube una carpeta (`..`) o dos carpetas (`...`) hacia atrás sin escribir `cd`. |
| `extract archivo.zip` | Descomprime cualquier archivo (`.zip`, `.rar`, `.tar.gz`, `.7z`...) automáticamente. |
| `duh` | Te dice cuánto espacio ocupa cada carpeta donde estás, ordenadas de menor a mayor. |
| `files` | Abre la carpeta actual en la ventana gráfica de **Dolphin**. |
| `fw-status` | Muestra el estado del cortafuegos UFW. |
| `ytvideo <enlace>` | Descarga un vídeo de YouTube en alta definición (MP4 1080p) si configuraste `just yt-dlp`. |
| `ytaudio <enlace>` | Descarga solo el audio de un vídeo en formato MP3. |

---

## 7. Mantenimiento: ¿Cómo mantengo mi ordenador al día?

Para mantener tu Golden Dog Linux limpio y actualizado una vez por semana o cuando quieras, solo necesitas dos comandos:

```bash
# 1. Actualizar todo el sistema base Debian y limpiar restos:
just update

# 2. Actualizar tus aplicaciones Flatpak y limpiar versiones antiguas:
just flatpak-update
just flatpak-clean
```

---

## 8. Preguntas Frecuentes (FAQ)

### ❓ ¿Se borrarán mis archivos o cambiará el aspecto de mi escritorio?
**No.** Ningún script borra tus documentos personales ni modifica el tema visual, fondos de pantalla o iconos de Golden Dog Linux.

### ❓ ¿Qué pasa si ejecuto el mismo comando dos veces por error?
**No pasa absolutamente nada.** Todos los scripts están diseñados para ser *idempotentes*: si detectan que un programa o configuración ya está instalado, simplemente te avisan con un `✅ Ya está instalado` y no vuelven a descargarlo.

### ❓ Tengo un ordenador con procesador Intel y otro con AMD, ¿qué comando uso?
Puedes usar `just post-install` (o `just setup-all`) en ambos: el script mira automáticamente qué procesador tienes y aplica la configuración correcta (`amd-setup.sh` o `intel-setup.sh`).

### ❓ ¿Dónde encuentro la documentación técnica avanzada?
Si más adelante quieres profundizar en contenedores Podman, máquinas virtuales KVM o programación en Python/Rust/Node/Java, puedes consultar el resto de guías detalladas en la carpeta [`Docs/`](./):
* [Configuración del Sistema (`setup_es.md`)](./setup_es.md)
* [Seguridad y Cortafuegos UFW (`seguridad_es.md`)](./seguridad_es.md)
* [Aplicaciones Flatpak (`apps_es.md`)](./apps_es.md)
* [Terminal y Atajos Bash/Zsh (`bash_es.md`)](./bash_es.md)
* [Lenguajes de Programación (`languages_es.md`)](./languages_es.md) y [Python con uv (`python_uv_es.md`)](./python_uv_es.md)
* [Entornos de Desarrollo e IA (`ide_es.md`)](./ide_es.md) y [Git (`git_es.md`)](./git_es.md)
* [Contenedores Podman (`podman_es.md`)](./podman_es.md) y [Virtualización KVM (`virtualizacion_es.md`)](./virtualizacion_es.md)
