# =========================================== MONITORING ===============================================================

# ----------------------- SETUP -------------------------------------------------------------------
setup:
	@./scripts/setup.sh

# ----------------------- KIBANA -------------------------------------------------------------------
start-kibana:
	@docker-compose up -d kibana
stop-kibana:
	@docker-compose stop kibana

# ------------------- ELASTICSEARCH ----------------------------------------------------------------
start-elasticsearch:
	@docker-compose up -d elasticsearch
stop-elasticsearch:
	@docker-compose stop elasticsearch


# ------------------- METRICBEAT -------------------------------------------------------------------
stop-metricbeat:
	@echo "== Stopping METRICBEAT=="
	@docker-compose stop metricbeat

# ------------------- MONITORING -------------------------------------------------------------------
create-network:
	@docker network create net || true
remove-network:
	@docker network rm net

start-monitoring: create-network start-elasticsearch start-kibana
	@docker-compose up -d metricbeat
	@echo "================= Monitoring STARTED !!!"

stop-monitoring: stop-metricbeat
	@docker-compose stop
	@echo "================= Monitoring STOPPED !!!"

stop-monitoring-host:
	@docker-compose stop metricbeat-host
	@docker-compose rm -f metricbeat-host || true

start-monitoring-host: start-elasticsearch start-kibana
	@docker-compose up -d metricbeat-host

build:
	@docker-compose build


# =================================================== MONGODB ==========================================================
compose-mongodb=docker-compose -f docker-compose.mongodb.yml -p mongodb
start-mongodb:
	@$(compose-mongodb) up -d mongodb
stop-mongodb:
	@$(compose-mongodb) stop mongodb


start-all: start-mongodb 

stop-all: stop-mongodb 

clean:
	@./scripts/clean.sh


install: clean setup start-monitoring-host start-monitoring start-all
