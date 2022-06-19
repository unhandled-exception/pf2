#!/bin/bash

MYSQL_IMAGE="mysql/mysql-server:5.7"
if [[ `uname -m` == 'arm64' ]]; then
  MYSQL_IMAGE="beercan1989/arm-mysql:5.7"
fi

POSTGRES_IMAGE="postgres:13"

# sudo docker pull mysql/mysql-server:$MYSQL_IMAGE_TAG
docker run --rm --name=pf2-ut-mysql -p 8306:3306 \
    -e MYSQL_USER=test \
    -e MYSQL_PASSWORD=test \
    -e MYSQL_DATABASE=mysql_test \
    -d "$MYSQL_IMAGE"

# docker pull postgres:$POSTGRES_IMAGE_TAG
docker run --rm --name=pf2-ut-postgres -p 8432:5432 \
    -e POSTGRES_USER=test \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_DB=pg_test \
    -d "$POSTGRES_IMAGE" \
&& sleep 4 \
&& psql postgres://test:test@127.0.0.1:8432/pg_test -c 'create extension if not exists pgcrypto'

# docker pull kennethreitz/httpbin
docker run --rm --name=pf2-ut-httpbin -p 8880:80 -d kennethreitz/httpbin
