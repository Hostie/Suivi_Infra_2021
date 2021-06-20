#!/usr/bin/env bash

sudo setfacl -m u:1000:rw /var/run/docker.sock && echo "=> ACLs on /var/run/docker.sock OK"
sudo sysctl -w vm.max_map_count=262144 && echo "=> vm.max_map_count=262144 OK"
docker network create metricbeat || true
docker-compose build
