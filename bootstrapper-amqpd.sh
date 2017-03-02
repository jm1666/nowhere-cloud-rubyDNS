#!/bin/bash

export DATABASE_URL="mysql2://$MYSQL_USER:$MYSQL_PASS@mysql/$MYSQL_DB"

/usr/local/bin/ruby /srv/amqpd.rb
