# First Version 20170212
FROM ruby:2.3.3-alpine

RUN apk --no-cache add ruby-mysql2

COPY bootstrapper.sh /srv

COPY Gemfile /srv

COPY dnsd.rb /srv

RUN BUNDLE_GEMFILE=/srv/Gemfile bundler install --without rest_api amqp_api

ENV DNS_TTL 10
ENV UPSTREAM_DNS1_IP bind1
ENV UPSTREAM_DNS1_PORT 53
ENV UPSTREAM_DNS2_IP bind2
ENV UPSTREAM_DNS2_PORT 53
ENV DNS_SUFFIX myzone.dev
ENV DATABASE_URL mysql2://default:default@mysql/default

ENTRYPOINT ["/srv/bootstrapper.sh"]
