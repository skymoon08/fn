#!/bin/bash
set -exo pipefail

source ./helpers.sh

function remove_system_containers {
    docker rm -fv func-mysql-system-test 2>/dev/null || true
    docker rm -fv func-postgres-system-test 2>/dev/null || true
}

remove_system_containers

case "$1" in
    "sqlite3" )
    rm -fr /tmp/fn_system_tests.db
    touch /tmp/fn_system_tests.db
    export FN_DB_URL="sqlite3:///tmp/fn_system_tests.db"
    ;;

    "mysql" )
    DB_CONTAINER="func-mysql-system-test"
    docker rm -fv ${DB_CONTAINER} || echo No prev mysql test db container
    docker run --name ${DB_CONTAINER} -p 3307:3306 -e MYSQL_DATABASE=funcs -e MYSQL_ROOT_PASSWORD=root -d mysql
    MYSQL_HOST=`host ${DB_CONTAINER}`
    MYSQL_PORT=3307
    export FN_DB_URL="mysql://root:root@tcp(${MYSQL_HOST}:${MYSQL_PORT})/funcs"
    wait_for_db ${MYSQL_HOST} ${MYSQL_PORT} 5
    ;;

    "postgres" )
    DB_CONTAINER="func-postgres-system-test"
    docker rm -fv ${DB_CONTAINER} || echo No prev test db container
    docker run --name ${DB_CONTAINER} -e "POSTGRES_DB=funcs" -e "POSTGRES_PASSWORD=root"  -p 5433:5432 -d postgres:9.3-alpine
    POSTGRES_HOST=`host ${DB_CONTAINER}`
    POSTGRES_PORT=5433
    export FN_DB_URL="postgres://postgres:root@${POSTGRES_HOST}:${POSTGRES_PORT}/funcs?sslmode=disable"
    wait_for_db ${POSTGRES_HOST} ${POSTGRES_PORT} 5
    ;;
esac

# avoid port conflicts with api_test.sh which are run in parallel
FN_API_URL="http://localhost:8085"
cd test/fn-system-tests && FN_DB_URL=${FN_DB_URL} FN_API_URL=${FN_API_URL} go test -v -parallel ${2:-1} ./...; cd ../../

remove_system_containers
