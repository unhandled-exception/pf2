#!/bin/bash

DB_HOST="${CI_TESTS_DIND_HOST:-127.0.0.1}"

MYSQL_57_IMAGE="mysql/mysql-server:5.7"
if [[ `uname -m` == 'arm64' ]]; then
  MYSQL_57_IMAGE="beercan1989/arm-mysql:5.7"
fi

MYSQL_8_IMAGE="mysql:8.4"
POSTGRES_IMAGE="postgres:17"

# docker pull kennethreitz/httpbin
docker run --rm --name=pf2-ut-httpbin -p 8880:80 -d kennethreitz/httpbin

# sudo docker pull mysql/mysql-server:$MYSQL_IMAGE_TAG
docker run --rm --name=pf2-ut-mysql-57 -p 8306:3306 \
    -e MYSQL_USER=test \
    -e MYSQL_PASSWORD=test_57 \
    -e MYSQL_DATABASE=mysql_test_57 \
    -d "$MYSQL_57_IMAGE"

# sudo docker pull mysql/mysql-server:$MYSQL_IMAGE_TAG
docker run --rm --name=pf2-ut-mysql-8 -p 9306:3306 \
    -e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_USER=test \
    -e MYSQL_PASSWORD=test_8 \
    -e MYSQL_DATABASE=mysql_test_8 \
    -d "$MYSQL_8_IMAGE"

# docker pull postgres:$POSTGRES_IMAGE_TAG
docker run --rm --name=pf2-ut-postgres -p 8432:5432 \
    -e POSTGRES_USER=test \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_DB=pg_test \
    -d "$POSTGRES_IMAGE"

echo "waiting for postgres container..."
for ((i=0 ; i<20 ; i++))
do
    echo -n "${i}: "
    if ( psql postgres://test:test@${DB_HOST}:8432/pg_test -c 'select 1' > /dev/null ) ; then
      break
    fi

    sleep 5
done

psql postgres://test:test@${DB_HOST}:8432/pg_test -c 'create extension if not exists pgcrypto'

docker container ls
