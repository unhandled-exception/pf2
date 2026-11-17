#!/bin/bash

MYSQL_57_IMAGE="dh-mirror.gitverse.ru/mysql/mysql-server:5.7"
if [[ `uname -m` == 'arm64' ]]; then
  MYSQL_57_IMAGE="dh-mirror.gitverse.ru/beercan1989/arm-mysql:5.7"
fi

MYSQL_8_IMAGE="dh-mirror.gitverse.ru/mysql:8.4"
POSTGRES_IMAGE="dh-mirror.gitverse.ru/postgres:18"

docker run --rm --name=pf2-ut-httpbin \
    -p 127.0.0.1:8080:8080 \
    -d dh-mirror.gitverse.ru/mccutchen/go-httpbin

docker run --rm --name=pf2-ut-mysql-db-57 \
    -e MYSQL_USER=test \
    -e MYSQL_PASSWORD=test_57 \
    -e MYSQL_DATABASE=mysql_test_57 \
    -p 127.0.0.1:5306:3306 \
    -d "$MYSQL_57_IMAGE"

docker run --rm --name=pf2-ut-mysql-db-8 \
    -e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_USER=test \
    -e MYSQL_PASSWORD=test_8 \
    -e MYSQL_DATABASE=mysql_test_8 \
    -p 127.0.0.1:8306:3306 \
    -d "$MYSQL_8_IMAGE"

docker run --rm --name=pf2-ut-postgres-db  \
    -e POSTGRES_USER=test \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_DB=pg_test \
    -p 127.0.0.1:9432:5432 \
    -d "$POSTGRES_IMAGE"

echo "waiting for postgres container..."
for ((i=0 ; i<20 ; i++))
do
    if ( pg_isready -h 127.0.0.1 -p 9432 -U test -t 5 > /dev/null ); then
        break
    fi
    sleep 5
done

psql postgres://test:test@127.0.0.1:9432/pg_test -c 'create extension if not exists pgcrypto'

docker container ls
