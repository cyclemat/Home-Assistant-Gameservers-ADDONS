FROM ghcr.io/home-assistant/amd64-base-debian:bookworm

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Wine + Xvfb + Libs (+ xauth Fix!)
RUN dpkg --add-architecture i386 \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl tar bash \
    xvfb xauth x11-xserver-utils \
    wine wine32 wine64 \
    lib32gcc-s1 lib32stdc++6 \
  && rm -rf /var/lib/apt/lists/*

# SteamCMD (Palworld-Fix: IPv4 + Retries)
RUN mkdir -p /opt/steamcmd \
  && curl -4 -fL --retry 8 --retry-delay 2 --connect-timeout 15 \
     https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
     -o /tmp/steamcmd.tgz \
  && tar -xzf /tmp/steamcmd.tgz -C /opt/steamcmd \
  && rm -f /tmp/steamcmd.tgz \
  && chmod +x /opt/steamcmd/steamcmd.sh \
  && /opt/steamcmd/steamcmd.sh +quit || true

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
