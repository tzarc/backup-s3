FROM debian:bullseye-slim

LABEL maintainer="hleroy@hleroy.com"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    gnupg \
    cron \
    python3-setuptools \
    python3-pip \
    python3-wheel \
    && rm -rf /var/lib/apt/lists/*

# Install MariaDB client
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Add Postgres repository configuration
RUN echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > \
    /etc/apt/sources.list.d/pgdg.list

# Import the repository signing key
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Install the latest version of PostgreSQL client
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install awscli
RUN pip3 install awscli

# Copy scripts
COPY *.sh /
RUN chmod +x *.sh

ENTRYPOINT ["/start.sh"]
CMD [""]
