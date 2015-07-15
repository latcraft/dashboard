#!/bin/bash 

docker run  --name dashboard      \
  -h local-dashboard.latcraft.lv  \
  -p 3030:3030                    \
  -v "`pwd`:/vagrant"             \
  -it                             \
  "latcraft_dashboard:latest"

