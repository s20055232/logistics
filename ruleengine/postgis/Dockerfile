# PostGIS + pg_uuidv7 image for CNPG (no TimescaleDB)
FROM postgis/postgis:17-3.4

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
