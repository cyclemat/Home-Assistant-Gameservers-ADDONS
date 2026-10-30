FROM python:3.11-bookworm

ARG BUILD_VERSION=0.1.0
ARG BUILD_ARCH=amd64
LABEL io.hass.type="addon" io.hass.version="${BUILD_VERSION}" io.hass.arch="${BUILD_ARCH}"

ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y --no-install-recommends \
    git postgresql postgresql-client redis-server gcc g++ make libffi-dev libssl-dev \
    libpq-dev tini ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/houdini
RUN git clone --depth 1 https://github.com/solero/houdini.git /opt/houdini \
    && python -m pip install --no-cache-dir -r requirements.txt
COPY run.sh /usr/local/bin/run-houdini
RUN chmod +x /usr/local/bin/run-houdini
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/run-houdini"]
