## FINAL IMAGE ##

ARG DEBIAN_IMAGE=debian:bookworm-slim
ARG KUBECTL_VERSION="1.33.2"
ARG YQ_VERSION="4.47.1"

FROM --platform=${TARGETPLATFORM} ${DEBIAN_IMAGE}

# ARG must be redeclared after each FROM
ARG KUBECTL_VERSION
ARG YQ_VERSION
ARG TARGETARCH

# Providing to environment, for easy information gathering.
ENV KUBECTL_VERSION ${KUBECTL_VERSION}

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates libssl3 openssh-client \
  && curl --retry 6 -LsfO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl \
  && chmod +x kubectl \
  && mv kubectl /usr/local/bin/kubectl \
  && curl --retry 6 -LsfO https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_$TARGETARCH \
  && chmod +x yq_linux_$TARGETARCH \
  && mv yq_linux_$TARGETARCH /usr/local/bin/yq

# Default to non-root user
USER 65534:65534
ENV HOME=/tmp/kube
