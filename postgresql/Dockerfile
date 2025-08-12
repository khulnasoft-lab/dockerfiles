ARG DEBIAN_IMAGE=debian:bookworm-slim
FROM --platform=${TARGETPLATFORM} ${DEBIAN_IMAGE} AS build

ARG BUILD_DIR=/tmp/build
ARG PG_VERSION=17.5

ENV LANG=C.UTF-8

# install runtime deps
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  bzip2 \
  ca-certificates \
  libffi-dev \
  libssl-dev \
  libyaml-dev \
  busybox \
  zlib1g-dev \
  coreutils \
  libossp-uuid16 \
  curl \
  gnupg2 \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p ${BUILD_DIR}

# Install Postgresql from source
RUN buildDeps=' \
  autoconf \
  bison \
  flex \
  gcc \
  libbz2-dev \
  libglib2.0-dev \
  libncurses-dev \
  libedit-dev \
  libxml2-dev \
  libossp-uuid-dev \
  libxslt-dev \
  make' \
  && apt-get update \
  && apt-get install -y --no-install-recommends $buildDeps \
  && rm -rf /var/lib/apt/lists/* \
  && cd ${BUILD_DIR} \
  && curl --retry 6 -sfo postgresql.tar.gz https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz \
  && tar -xzf postgresql.tar.gz \
  && rm postgresql.tar.gz \
  && cd postgresql-${PG_VERSION} \
  && ./configure --prefix=/usr/local/psql --with-libedit-preferred --disable-rpath --with-openssl --with-uuid=ossp \
  && make -j "$(nproc)" world-bin \
  && make -C src/bin install \
  && make -C src/include install \
  && make -C src/interfaces install \
  && rm -Rf /usr/local/psql/share \
  && cd \
  && apt-get purge -y --auto-remove $buildDeps \
  && rm -rf ${BUILD_DIR}

FROM --platform=${TARGETPLATFORM} scratch
COPY --from=build /usr/local/psql /usr/local/psql
