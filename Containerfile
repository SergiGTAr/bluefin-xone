# Bluefin DX NVIDIA Open + xonedo (dongle inalámbrico Xbox)
#
# - kmod-xone y xone-kmod-common salen de ghcr.io/ublue-os/akmods, ya compilados
#   y firmados por Universal Blue para el kernel EXACTO de la imagen base.
# - El firmware de Microsoft NO se redistribuye en este repo: se extrae en el
#   build del paquete xone-kmod-common de negativo17 (fedora-multimedia).
# - El módulo pide xone_dongle_<PID>.bin; para el dongle 045e:02fe es
#   xone_dongle_02fe.bin (idéntico al FW_ACC_00U.bin oficial de Microsoft).
ARG BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable
ARG AKMODS_IMAGE=ghcr.io/ublue-os/akmods:coreos-stable-44
ARG KERNEL=unknown
ARG BASE_DIGEST=unknown
ARG AKMODS_DIGEST=unknown
ARG RECIPE_REVISION=dev

FROM ${AKMODS_IMAGE} AS akmods

FROM ${BASE_IMAGE}

ARG KERNEL
ARG BASE_DIGEST
ARG AKMODS_DIGEST
ARG RECIPE_REVISION

LABEL org.opencontainers.image.title="bluefin-xone" \
      org.opencontainers.image.description="Bluefin DX NVIDIA Open + xonedo para el dongle inalambrico de Xbox" \
      org.bluefin-xone.base-digest="${BASE_DIGEST}" \
      org.bluefin-xone.akmods-digest="${AKMODS_DIGEST}" \
      org.bluefin-xone.kernel="${KERNEL}" \
      org.bluefin-xone.recipe-revision="${RECIPE_REVISION}"

# RPMs de xone precompilados/firmados por Universal Blue
COPY --from=akmods /rpms/kmods/kmod-xone-*.rpm /rpms/common/xone-kmod-common-*.rpm /tmp/xone-rpms/

RUN set -eux; \
    KVER="$(ls /usr/lib/modules)"; \
    echo "Kernel de la imagen base: ${KVER}"; \
    if [ "${KERNEL}" != "unknown" ] && [ "${KERNEL}" != "${KVER}" ]; then \
      echo "ERROR: KERNEL=${KERNEL} no coincide con la imagen=${KVER}" >&2; \
      exit 1; \
    fi; \
    rpm -qp --qf '[%{REQUIRENAME} %{REQUIREVERSION}\n]' /tmp/xone-rpms/kmod-xone-*.rpm \
      | grep -qx "kernel-uname-r ${KVER}"; \
    dnf5 -y download --from-repo=fedora-multimedia --destdir=/tmp/xone-fw xone-kmod-common; \
    RPM="$(ls /tmp/xone-fw/*.rpm | head -n1)"; \
    rpm2archive "${RPM}" > /tmp/xone-fw/firmware.tgz; \
    mkdir -p /tmp/xone-fw/extract; \
    tar -xzf /tmp/xone-fw/firmware.tgz -C /tmp/xone-fw/extract ./usr/lib/firmware; \
    install -Dm644 /tmp/xone-fw/extract/usr/lib/firmware/*.bin /usr/lib/firmware/; \
    dnf5 -y install --setopt=localpkg_gpgcheck=0 /tmp/xone-rpms/*.rpm; \
    rm -rf /tmp/xone-rpms /tmp/xone-fw /run/dnf /run/libdnf5 /var/cache/libdnf5 /var/lib/dnf /var/log/dnf5.log; \
    rm -f /var/cache/ldconfig/aux-cache; \
    depmod -a "${KVER}"; \
    bootc container lint
