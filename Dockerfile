FROM alpine:3.22

RUN apk add --no-cache \
        libp11 \
        openssl \
        pcsc-lite-libs \
        yubico-piv-tool \
        yubico-piv-tool-libs

WORKDIR /work

ENV LANG=C \
    LC_ALL=C

ENTRYPOINT ["/bin/sh"]
