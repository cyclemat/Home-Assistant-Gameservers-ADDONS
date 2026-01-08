# Hass.io Debian base (glibc) + s6 overlay
FROM ghcr.io/hassio-addons/debian-base:stable

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# 32-bit libs for SteamCMD + tools
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates curl jq gosu \
    libc6:i386 libstdc++6:i386 libgcc-s1:i386 \
    libcurl4:i386 \
    libncurses6:i386 libtinfo6:i386 \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Create unprivileged steam user
RUN useradd -m -u 1000 -s /bin/bash steam || true

# Install SteamCMD
RUN mkdir -p /opt/steamcmd \
 && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar -xz -C /opt/steamcmd \
 && chmod +x /opt/steamcmd/steamcmd.sh \
 && chown -R steam:steam /opt/steamcmd

WORKDIR /data

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
