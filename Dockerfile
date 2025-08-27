# Usa la imagen oficial que ya trae mongodump yea
FROM mongo:7-jammy

# Utilidades necesarias: cron, bash, tzdata, certificados, coreutils, findutils, curl, python3, pip
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      cron bash tzdata ca-certificates coreutils findutils curl python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Directorio de trabajo y volumen para backups
WORKDIR /app
VOLUME ["/backups"]

# Instalar boto3 para AWS SDK
RUN pip3 install --no-cache-dir boto3

# Copiar scripts
COPY entrypoint.sh /entrypoint.sh
COPY backup.sh /app/backup.sh
COPY notify.sh /app/notify.sh
COPY healthcheck.sh /app/healthcheck.sh
COPY s3_upload.py /app/s3_upload.py

# Permisos de ejecución
RUN chmod +x /entrypoint.sh /app/backup.sh /app/notify.sh /app/healthcheck.sh

# Variables por defecto
ENV TZ=Etc/UTC \
    OUTPUT_DIR=/backups \
    HEALTH_MAX_AGE_MIN=6 \
    HEALTH_GRACE_PERIOD_MIN=1445

# Healthcheck: cron vivo y último backup OK reciente
HEALTHCHECK --interval=2m --timeout=20s --retries=3 CMD /app/healthcheck.sh

# Entrypoint (levanta cron en foreground si hay CRON_SCHEDULE)
ENTRYPOINT ["/entrypoint.sh"]
