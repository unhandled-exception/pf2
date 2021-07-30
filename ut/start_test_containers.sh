#!/bin/sh

MYSQL_IMAGE_TAG="5.7"
POSTGRES_IMAGE_TAG="13"

# sudo docker pull mysql/mysql-server:$MYSQL_IMAGE_TAG
sudo docker run --rm --name=pf2-ut-mysql -p 8306:3306 \
    -e MYSQL_USER=test \
    -e MYSQL_PASSWORD=test \
    -e MYSQL_DATABASE=mysql_test \
    -d mysql/mysql-server:$MYSQL_IMAGE_TAG

# sudo docker pull postgres:$POSTGRES_IMAGE_TAG
sudo docker run --rm --name=pf2-ut-postgres -p 8432:5432 \
    -e POSTGRES_USER=test \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_DB=pg_test \
    -d postgres:$POSTGRES_IMAGE_TAG \
&& sleep 4 \
&& psql postgres://test:test@127.0.0.1:8432/pg_test -c 'create extension if not exists pgcrypto'

# sudo docker pull kennethreitz/httpbin
sudo docker run --rm --name=pf2-ut-httpbin -p 8880:80 -d kennethreitz/httpbin
