# Basisimage gepinnt, damit Builds reproduzierbar bleiben (bei Bedarf bewusst anheben)
FROM ghcr.io/hassio-addons/debian-base:9.5.1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    bash \
    coreutils \
    sed \
    grep \
    findutils \
    tar \
    util-linux \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
