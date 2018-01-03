FROM alpine
MAINTAINER Djennadi Rabah <rabah.djennadi@holonix.it>

# Update, install tooling and some basic setup
RUN apk add --no-cache \
        bash \
        bash-completion \
        bzip2 \
        coreutils \
        curl \
        gettext \
        gzip \
        jq \
        libstdc++ \
        openjdk8-jre-base \
        openssl \
        sqlite \
        supervisor \
        tar \
        wget \
    && echo "progress = dot:giga" | tee /etc/wgetrc \
    && mkdir /opt \
    && wget https://gitlab.com/andmarios/checkport/uploads/3903dcaeae16cd2d6156213d22f23509/checkport -O /usr/local/bin/checkport \
    && chmod +x /usr/local/bin/checkport \
    && mkdir /etc/supervisord.d /etc/supervisord.templates.d

# Create Landoop configuration directory
RUN mkdir /usr/share/landoop

# Add Confluent Distribution
ENV CP_VERSION="3.3.1" KAFKA_VERSION="0.11.0.1"
ARG CP_URL="https://packages.confluent.io/archive/3.3/confluent-oss-${CP_VERSION}-2.11.tar.gz"
RUN wget "$CP_URL" -O /opt/confluent.tar.gz \
    && mkdir -p /opt/confluent \
    && tar --no-same-owner --strip-components 1 -xzf /opt/confluent.tar.gz -C /opt/confluent \
    && mkdir /opt/confluent/logs && chmod 1777 /opt/confluent/logs \
    && rm -rf /opt/confluent.tar.gz \
    && ln -s /opt/confluent "/opt/confluent-${CP_VERSION}"


# Add Stream Reactor and Elastic Search (for elastic connector)
# ARG STREAM_REACTOR_URL=https://archive.landoop.com/third-party/stream-reactor/stream-reactor-0.3.0_3.3.0.tar.gz
# RUN wget "${STREAM_REACTOR_URL}" -O stream-reactor.tar.gz \
#     && mkdir -p /opt/connectors \
#     && tar -xzf stream-reactor.tar.gz --no-same-owner --strip-components=1 -C /opt/connectors \
#     && rm /stream-reactor.tar.gz \
#     && wget https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/2.4.1/elasticsearch-2.4.1.tar.gz \
#     && tar xf /elasticsearch-2.4.1.tar.gz --no-same-owner \
#     && mv /elasticsearch-2.4.1/lib/*.jar /opt/connectors/kafka-connect-elastic/ \
#     && rm -rf /elasticsearch-2.4.1* \
#     && echo "plugin.path=/opt/connectors,/extra-connect-jars,/connectors" >> /opt/confluent/etc/schema-registry/connect-avro-distributed.properties

# Create system symlinks to Confluent's binaries
ADD binaries /opt/confluent/bin-install
RUN bash -c 'for i in $(find /opt/confluent/bin-install); do ln -s $i /usr/local/bin/$(echo $i | sed -e "s>.*/>>"); done' \
    && cd /opt/confluent/bin \
    && ln -s kafka-run-class kafka-run-class.sh

# Configure Confluent
RUN echo "access.control.allow.methods=GET,POST,PUT,DELETE,OPTIONS" >> /opt/confluent/etc/schema-registry/schema-registry.properties \
    && echo 'access.control.allow.origin=*' >> /opt/confluent/etc/schema-registry/schema-registry.properties \
    && echo "access.control.allow.methods=GET,POST,PUT,DELETE,OPTIONS" >> /opt/confluent/etc/kafka-rest/kafka-rest.properties \
    && echo 'access.control.allow.origin=*' >> /opt/confluent/etc/kafka-rest/kafka-rest.properties \
    && echo "access.control.allow.methods=GET,POST,PUT,DELETE,OPTIONS" >> /opt/confluent/etc/schema-registry/connect-avro-distributed.properties \
    && echo 'access.control.allow.origin=*' >> /opt/confluent/etc/schema-registry/connect-avro-distributed.properties

# # Add and setup Kafka Manager
# RUN wget https://archive.landoop.com/third-party/kafka-manager/kafka-manager-1.3.2.1.zip \
#          -O /kafka-manager-1.3.2.1.zip \
#     && unzip /kafka-manager-1.3.2.1.zip -d /opt \
#     && rm -rf /kafka-manager-1.3.2.1.zip


# Add dumb init and quickcert
#  RUN wget https://github.com/Yelp/dumb-init/releases/download/v1.2.0/dumb-init_1.2.0_amd64 -O /usr/local/bin/dumb-init \
#    && wget https://github.com/andmarios/quickcert/releases/download/1.0/quickcert-1.0-linux-amd64-alpine -O /usr/local/bin/quickcert \
#    && chmod 0755 /usr/local/bin/dumb-init /usr/local/bin/quickcert


# Add and Setup Schema-Registry-Ui
ARG SCHEMA_REGISTRY_UI_URL="https://github.com/Landoop/schema-registry-ui/releases/download/v.0.9.3/schema-registry-ui-0.9.3.tar.gz"
RUN wget "$SCHEMA_REGISTRY_UI_URL" -O /schema-registry-ui.tar.gz \
    && mkdir -p /var/www/schema-registry-ui \
    && tar xzf /schema-registry-ui.tar.gz -C /var/www/schema-registry-ui \
    && rm -f /schema-registry-ui.tar.gz
COPY web/registry-ui-env.js /var/www/schema-registry-ui/env.js

# Add and Setup Kafka-Topics-Ui
ARG KAFKA_TOPICS_UI_URL="https://github.com/Landoop/kafka-topics-ui/releases/download/v0.9.3/kafka-topics-ui-0.9.3.tar.gz"
RUN wget "$KAFKA_TOPICS_UI_URL" -O /kafka-topics-ui.tar.gz \
    && mkdir /var/www/kafka-topics-ui \
    && tar xzf /kafka-topics-ui.tar.gz -C /var/www/kafka-topics-ui \
    && rm -f /kafka-topics-ui.tar.gz
COPY web/topics-ui-env.js /var/www/kafka-topics-ui/env.js

# Add and Setup Kafka-Connect-UI
# ARG KAFKA_CONNECT_UI_URL="https://github.com/Landoop/kafka-connect-ui/releases/download/v.0.9.3/kafka-connect-ui-0.9.3.tar.gz"
# RUN wget "$KAFKA_CONNECT_UI_URL" -O /kafka-connect-ui.tar.gz \
#     && mkdir /var/www/kafka-connect-ui \
#     && tar xzf /kafka-connect-ui.tar.gz -C /var/www/kafka-connect-ui \
#    && rm -f /kafka-connect-ui.tar.gz
# COPY web/connect-ui-env.js /var/www/kafka-connect-ui/env.js

# Add and setup Caddy Server
ARG CADDY_URL=https://github.com/mholt/caddy/releases/download/v0.9.5/caddy_linux_amd64.tar.gz
RUN wget "$CADDY_URL" -O /caddy.tgz \
    && mkdir -p /opt/caddy \
    && tar xzf /caddy.tgz -C /opt/caddy \
    && mv /opt/caddy/caddy_linux_amd64 /opt/caddy/caddy \
    && rm -f /caddy.tgz
ADD web/Caddyfile /usr/share/landoop

# Add data-channels UI
COPY web/index.html web/env.js web/env-webonly.js /var/www/
COPY web/img /var/www/img
RUN ln -s /var/log /var/www/logs


# Add executables, settings and configuration
ADD extras/ /usr/share/landoop/
ADD supervisord.conf /etc/supervisord.conf
ADD supervisord.templates.d/* /etc/supervisord.templates.d/
ADD setup-and-run.sh /usr/local/bin/
ADD https://github.com/Landoop/kafka-autocomplete/releases/download/0.3/kafka /usr/share/landoop/kafka-completion
RUN chmod +x /usr/local/bin/setup-and-run.sh \
    && ln -s /usr/share/landoop/bashrc /root/.bashrc \
    && cat /etc/supervisord.templates.d/* > /etc/supervisord.d/01-fast-data.conf

ARG BUILD_BRANCH
ARG BUILD_COMMIT
ARG BUILD_TIME
ARG DOCKER_REPO=local
RUN echo "BUILD_BRANCH=${BUILD_BRANCH}"      | tee /build.info \
    && echo "BUILD_COMMIT=${BUILD_COMMIT}"   | tee -a /build.info \
    && echo "BUILD_TIME=${BUILD_TIME}"       | tee -a /build.info \
    && echo "DOCKER_REPO=${DOCKER_REPO}"     | tee -a /build.info \
    && echo "KAFKA_VERSION=${KAFKA_VERSION}" | tee -a /build.info \
    && echo "CP_VERSION=${CP_VERSION}"       | tee -a /build.info

EXPOSE 2181 3030 3031 8081 8082 9092
# ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["/usr/local/bin/setup-and-run.sh"]
