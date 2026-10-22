# bluefin-xone

[![Build](https://github.com/SergiGTAr/bluefin-xone/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/SergiGTAr/bluefin-xone/actions/workflows/build.yml)
[![Bluefin](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/SergiGTAr/bluefin-xone/main/state/badge.json)](https://github.com/SergiGTAr/bluefin-xone/blob/main/state/last-build.json)

Capa OCI sobre **Bluefin DX NVIDIA Open** que añade **xonedo** (`kmod-xone`)
para el dongle inalámbrico de Xbox, sin compilar nada en el PC y sin tocar
Secure Boot.

- Base: `ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable`
- Driver: `kmod-xone` + `xone-kmod-common` de `ghcr.io/ublue-os/akmods`
  (precompilado y firmado por Universal Blue para el kernel exacto).
- Firmware: se extrae en el build del paquete `xone-kmod-common` de
  negativo17 (`fedora-multimedia`); no se redistribuye en este repo.
- Firma: cosign keyless (OIDC de GitHub Actions).

## Instalar en el PC

```bash
sudo bootc switch --transport registry ghcr.io/sergigtar/bluefin-xone:stable
sudo bootc status
sudo systemctl reboot
```

El primer arranque tarda un poco más porque despliega la imagen. Puedes volver
atrás en cualquier momento con `sudo bootc rollback`.

## Comprobar que el mando va

```bash
lsusb -d 045e:02fe
lsmod | grep xone
cat /sys/bus/usb/drivers/xone-dongle/*/active_clients
```

Emparejar (solo hace falta la primera vez):

```bash
echo 1 | sudo tee /sys/bus/usb/drivers/xone-dongle/*/pairing
```

Mantén pulsado el botón de sincronización del mando hasta que parpadee y
enciéndelo con el botón Xbox. `active_clients` debe devolver `1`.

El mando por cable sigue usando `xpad`; `xonedo` solo se ocupa del dongle.

## Cómo se actualiza

El workflow se ejecuta **cada 6 horas** y también a mano. En cada pasada:

1. Lee el digest y el kernel de `bluefin-dx-nvidia-open:stable`.
2. Busca el `akmods` exacto para ese kernel (`coreos-stable-44-<kernel>`).
3. Si ya existe una imagen publicada con la misma base, los mismos akmods y la
   misma receta, **no construye nada** (pasada rápida).
4. Si cambió algo, construye solo la capa nueva y publica
   `ghcr.io/sergigtar/bluefin-xone:stable`.

Tu PC lo recoge con `uupd`/`bootc upgrade`, que ya corre a diario. El retraso
típico es de horas, no de días. En un día en el que Universal Blue cambie el
kernel, el workflow espera a que el `kmod-xone` de akmods esté publicado para
ese kernel; si aún no está, no rompe nada: lo salta y reintenta en la
siguiente pasada.

## Cómo saber si se ha ejecutado

- **Badge de Build** arriba: verde = última ejecución correcta; rojo = fallo.
- **Badge Bluefin**: muestra la última versión de Bluefin y el kernel con los
  que se construyó la imagen (`state/badge.json`).
- **`state/last-build.json`**: fecha, versión de Bluefin, kernel, digests de
  base/akmods, digest de la imagen y enlace al run.
- **Pestaña Actions** del repo: historial completo y resumen de cada pasada.
- **GitHub te manda email** si falla un workflow (si tienes las notificaciones
  de Actions activadas en tu cuenta).
- Desde terminal:

```bash
gh run list --repo SergiGTAr/bluefin-xone --limit 10
gh run watch --repo SergiGTAr/bluefin-xone
```

Forzar una pasada:

```bash
gh workflow run build.yml --repo SergiGTAr/bluefin-xone
# o forzando rebuild aunque no haya cambios:
gh workflow run build.yml --repo SergiGTAr/bluefin-xone -f force=true
```

GitHub pausa los workflows programados tras 60 días sin actividad en el repo.
El workflow hace un commit en `state/` cada vez que construye, así que mientras
haya actualizaciones el cron sigue vivo. Si algún día ves que no se ejecuta,
pulsa **Run workflow** una vez.

## Seguridad

- No se añade ningún demonio, puerto ni servicio: solo un módulo de kernel y
  firmware.
- El `.ko` va firmado por la clave **`ublue kernel`**, que ya está inscrita en
  el MOK de Bluefin. Secure Boot puede estar activado y sigue funcionando.
- La imagen se firma con **cosign keyless**; no hay claves privadas guardadas
  en el repo. Verificación:

```bash
cosign verify \
  --certificate-identity "https://github.com/SergiGTAr/bluefin-xone/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/sergigtar/bluefin-xone:stable
```

- El firmware de Microsoft no se guarda en el repo: se extrae del RPM de
  negativo17 durante el build.

## Por qué no DKMS en el host

Bluefin es una imagen `bootc`: `/usr` es de solo lectura y el kernel forma
parte de la imagen. `dkms`/`akmods` no pueden escribir en
`/usr/lib/modules` de forma persistente; `usroverlay` se pierde al reiniciar y
`rpm-ostree install kmod-xone` bloquearía las actualizaciones de kernel por la
dependencia `kernel-uname-r`.

La forma canónica es construir una imagen derivada, que es exactamente lo que
hace este repo. El driver se compila una vez en el CI de Universal Blue
(`akmods`), se firma y tú solo consumes la capa resultante.

## Build local (fallback)

Si algún día quieres construirlo sin CI:

```bash
./rebuild.sh
```

o manualmente:

```bash
docker build -f Containerfile \
  --build-arg AKMODS_IMAGE=ghcr.io/ublue-os/akmods:coreos-stable-44 \
  -t localhost/bluefin-xone:local .
sudo bootc switch --transport docker-daemon localhost/bluefin-xone:local
```

## Créditos

- [`dlundqvist/xone`](https://github.com/dlundqvist/xone) y el fork `xonedo`
  para el dongle.
- [`ublue-os/akmods`](https://github.com/ublue-os/akmods) por los RPMs
  precompilados y firmados.
- negativo17 por empaquetar el firmware en `xone-kmod-common`.
- Project Bluefin / Universal Blue por la base y el modelo `bootc`.

## Licencia

El `Containerfile`, el workflow y el resto de este repo se publican bajo MIT.
El driver `xone` es GPLv2 y el firmware pertenece a Microsoft; no se
redistribuyen aquí.
