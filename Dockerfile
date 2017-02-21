# First Version 20170212
FROM ruby:2.4

RUN apt-get update && apt-get install -y ruby-mysql2 && apt-get clean

COPY bootstrapper.sh /srv

RUN chmod a+x /srv/bootstrapper.sh

COPY Gemfile /srv

COPY dnsd.rb /srv

RUN BUNDLE_GEMFILE=/srv/Gemfile bundler install --without rest_api amqp_api

ENV DNS_TTL 10
ENV DNS_SUFFIX nowhere.dev
ENV MYSQL_USER
ENV MYSQL_PASS
ENV MYSQL_DB
ENV USE_DOCKER_BIND false
ENV UPSTREAM_DNS1_IP
ENV UPSTREAM_DNS2_IP

ENTRYPOINT ["/srv/bootstrapper.sh"]
