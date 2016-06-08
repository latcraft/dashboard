#!/bin/bash 

docker run --name dashboard \
 -h local-dashboard.latcraft.lv \
 -p 3030:3030 \
 -v "`pwd`:/vagrant" \
 -v "`pwd`/.data/sqlite:/var/lib/sqlite" \
 -it \
 --rm \
 "latcraft_dashboard:latest"

