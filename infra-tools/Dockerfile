FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    tar \
    gzip \
    coreutils \
    mariadb-client \
    gnupg \
    rclone \
    tzdata

WORKDIR /app

COPY backup.sh /app/backup.sh
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/backup.sh /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
