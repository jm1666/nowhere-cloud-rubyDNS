# First Version 20170212
FROM ruby:2.4

COPY bootstrapper.sh /srv

RUN chmod a+x /srv/bootstrapper.sh

COPY Gemfile /srv

COPY dnsd.rb /srv

RUN BUNDLE_GEMFILE=/srv/Gemfile bundler install --without rest_api amqp_api

ENV DNS_TTL 10
ENV DNS_SUFFIX nowhere.dev
ENV MYSQL_USER change-me
ENV MYSQL_PASS change-me
ENV MYSQL_DB change-me
ENV USE_DOCKER_BIND false
ENV UPSTREAM_DNS1_IP 208.67.222.222
ENV UPSTREAM_DNS2_IP 208.67.220.220

ENTRYPOINT ["/srv/bootstrapper.sh"]
