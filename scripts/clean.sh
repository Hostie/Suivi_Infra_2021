#!/usr/bin/env bash

CONTAINERS=`docker ps | grep metricbeat | awk '{print $1}'`
[ ! -z "${CONTAINERS}" ] && docker rm -f ${CONTAINERS}
echo "All METRICBEAT containers removed !"
docker network rm net 2>&1 > /dev/null || true
exit 0
