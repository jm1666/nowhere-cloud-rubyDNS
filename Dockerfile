FROM ruby:2.4

COPY bootstrapper-amqpd.sh /srv

COPY bootstrapper-dnsd.sh /srv

COPY Gemfile /srv

COPY dnsd.rb /srv

COPY amqpd.rb /srv

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod a+x /srv/bootstrapper-amqpd.sh \
 && chmod a+x /srv/bootstrapper-dnsd.sh \
 && apt-get update \
 && apt-get install -y supervisor \
 && apt-get clean \
 && BUNDLE_GEMFILE=/srv/Gemfile bundler install --without rest_api

EXPOSE 53/udp 53/tcp

ENV DNS_TTL=10 \
    DNS_PORT=53 \
    DNS_SUFFIX=nowhere.dev \
    MYSQL_USER=change-me \
    MYSQL_PASS=change-me \
    MYSQL_DB=change-me \
    USE_DOCKER_BIND=false \
    UPSTREAM_DNS1_IP=208.67.222.222 \
    UPSTREAM_DNS1_PORT=53 \
    UPSTREAM_DNS2_IP=208.67.220.220 \
    UPSTREAM_DNS2_PORT=53 \
    AMQP_URI=amqp://nowhere-rabbitmq

ENTRYPOINT ["/usr/bin/supervisord"]
