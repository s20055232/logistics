# Build a TimescaleDB + PostGIS Docker image
# Reference: https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers
FROM postgis/postgis:17-3.5

# Install TimescaleDB
RUN apt-get update \
    && apt-get install -y lsb-release wget \
    && echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list \
    && wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add - \
    && apt-get update \
    && apt-get install -y "timescaledb-2-postgresql-${PG_MAJOR}" \
    && apt-get remove -y lsb-release wget \
    && rm -rf /var/lib/apt/lists/*

# Configure TimescaleDB preload
RUN echo "shared_preload_libraries = 'timescaledb'" >> /usr/share/postgresql/postgresql.conf.sample

# Install pg_uuidv7
RUN apt-get update && apt-get install -y wget \
    && wget -O /tmp/pg_uuidv7.tar.gz https://github.com/fboulnois/pg_uuidv7/releases/download/v1.7.0/pg_uuidv7.tar.gz \
    && tar -xzf /tmp/pg_uuidv7.tar.gz -C /tmp \
    && cp /tmp/${PG_MAJOR}/pg_uuidv7.so $(pg_config --pkglibdir)/ \
    && cp /tmp/pg_uuidv7--1.7.sql /tmp/pg_uuidv7.control $(pg_config --sharedir)/extension/ \
    && rm -rf /tmp/pg_uuidv7* /tmp/1[3-8] \
    && apt-get remove -y wget \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# CloudNativePG expects postgres user with UID 26
RUN usermod -u 26 postgres
USER 26