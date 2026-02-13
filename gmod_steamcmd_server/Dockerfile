ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:7.7.0
FROM $BUILD_FROM

ENV DEBIAN_FRONTEND=noninteractive

# SteamCMD + 32-bit runtime deps (Debian)
RUN dpkg --add-architecture i386   && apt-get update   && apt-get install -y --no-install-recommends     ca-certificates     curl     lib32gcc-s1     libstdc++6     libstdc++6:i386     libcurl4     libcurl4:i386     libtinfo6     libtinfo6:i386     libncurses6     libncurses6:i386     libssl3     libssl3:i386     unzip     tini   && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 steam   && mkdir -p /opt/steamcmd   && chown -R steam:steam /opt/steamcmd

USER steam
WORKDIR /opt/steamcmd
RUN curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz -o steamcmd_linux.tar.gz   && tar -xzf steamcmd_linux.tar.gz   && rm steamcmd_linux.tar.gz

USER root
WORKDIR /

COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/run.sh"]
