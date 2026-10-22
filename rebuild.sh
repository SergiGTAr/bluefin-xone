#!/usr/bin/env bash
# Fallback local: reconstruye la capa de Bluefin con xonedo para el kernel de la
# imagen base y la deja lista para el siguiente arranque.
#
# El camino recomendado es el CI de GitHub Actions (ver README). Este script
# existe solo por si algún día quieres construir sin CI.
set -euo pipefail

cd "$(dirname "$0")"

BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable}"
FEDORA_MAJOR="$(rpm -E %fedora)"
AKMODS_FLAVOR="${AKMODS_FLAVOR:-coreos-stable}"
AKMODS_IMAGE="${AKMODS_IMAGE:-ghcr.io/ublue-os/akmods:${AKMODS_FLAVOR}-${FEDORA_MAJOR}}"

echo ">> Imagen base : ${BASE_IMAGE}"
echo ">> Fedora      : ${FEDORA_MAJOR}"
echo ">> Akmods      : ${AKMODS_IMAGE}"

docker build \
  -f Containerfile \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg AKMODS_IMAGE="${AKMODS_IMAGE}" \
  -t localhost/bluefin-xone:stable \
  .

sudo bootc switch --transport docker-daemon localhost/bluefin-xone:stable
echo ">> Listo. Reinicia con: systemctl reboot"
