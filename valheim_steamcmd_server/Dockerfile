FROM ghcr.io/hassio-addons/debian-base:stable

ENV LANG=C.UTF-8
ENV STEAMCMD_DIR=/opt/steamcmd

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget tar gzip xz-utils \
    bash coreutils procps jq \
    lib32gcc-s1 lib32stdc++6 libc6-i386 lib32z1 \
    libstdc++6 libgcc-s1 libatomic1 \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${STEAMCMD_DIR} \
  && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
  | tar -xz -C ${STEAMCMD_DIR}

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
