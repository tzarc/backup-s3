FROM debian:13-slim
LABEL origmaintainer="hleroy@hleroy.com"
LABEL maintainer="nick@tzarc.org"

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    awscli \
    ca-certificates \
    wget \
    gnupg \
    cron \
    postgresql-common \
    && rm -rf /var/lib/apt/lists/*

# Install the latest version of PostgreSQL client
RUN /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
    && apt-get update && apt-get install -y --no-install-recommends postgresql-client-18 \
    && rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY *.sh /
RUN chmod +x *.sh

ENTRYPOINT ["/start.sh"]
CMD [""]
