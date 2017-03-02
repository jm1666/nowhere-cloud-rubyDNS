#!/bin/bash

if [ "$USE_DOCKER_BIND" = true ] ; then
  export UPSTREAM_DNS1_IP=`ping -c 1 bind1 | grep ^64 | cut -d' ' -f4 | tr -d :`
  export UPSTREAM_DNS2_IP=`ping -c 1 bind2 | grep ^64 | cut -d' ' -f4 | tr -d :`
fi

export DATABASE_URL="mysql2://$MYSQL_USER:$MYSQL_PASS@mysql/$MYSQL_DB"

/usr/local/bin/ruby /srv/dnsd.rb
