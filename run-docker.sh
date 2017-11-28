#!/usr/bin/env bash

IMAGE=devternity/event
NAME=dashboard
docker build -t ${IMAGE} .

(docker container ls -a | grep ${NAME}) && \
   (docker container rm -fv ${NAME} || echo "Could not remove ${NAME}")

mkdir -p .database
touch .database/latcraft.db

docker run -dit \
  -p 3030:3030 \
  -v $PWD:/app \
  -v $PWD/.database:/var/lib/sqlite \
  --name ${NAME} \
  ${IMAGE}

