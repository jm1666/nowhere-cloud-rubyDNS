# First Version 20170212
FROM ruby:2.4

RUN apt-get update && apt-get install -y ruby-mysql2 && apt-get clean

COPY bootstrapper.sh /srv

RUN chmod a+x /srv/bootstrapper.sh

COPY Gemfile /srv

COPY dnsd.rb /srv

RUN BUNDLE_GEMFILE=/srv/Gemfile bundler install --without rest_api amqp_api

ENV DNS_TTL 10
ENV UPSTREAM_DNS1_IP bind1
ENV UPSTREAM_DNS1_PORT 53
ENV UPSTREAM_DNS2_IP bind2
ENV UPSTREAM_DNS2_PORT 53
ENV DNS_SUFFIX nowhere.dev
ENV MYSQL_USER changeme
ENV MYSQL_PASS changeme
ENV MYSQL_DB changeme
ENV DATABASE_URL mysql2://$MYSQL_USER:$MYSQL_PASS@mysql/$MYSQL_DB

ENTRYPOINT ["/srv/bootstrapper.sh"]
