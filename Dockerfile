FROM python:slim

MAINTAINER hleroy <hleroy@hleroy.com>

# Install postgresql-client, mariadb-client and cron
RUN apt-get update \
      && apt-get install -q -y --no-install-recommends postgresql-client mariadb-client cron \
      && rm -rf /var/lib/apt/lists/*

# Install awscli
RUN pip install awscli

# Copy scripts
COPY *.sh /
RUN chmod +x *.sh

ENTRYPOINT ["/start.sh"]
CMD [""]
