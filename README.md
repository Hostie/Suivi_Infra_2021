# Suivi_Infra_2021

# Projet 

Le projet consiste en une infrastructure conteneurisée permettant la récupération de métriques d'une MongoDB. Elle repose sur la technologie Docker et sur différentes technologies : Traeffik, Elastic Search, Kibana, Node et Metricbeat

# Pré-requis

- Ubuntu 20.04 LTS
- Docker
- Github


# Lancement de l'infrastructure 

Après avoir intaller le binaire Docker sur votre machine (https://docs.docker.com/engine/install/ubuntu/), clonez le projet sur votre machine via la commande :

``` git clone https://github.com/Hostie/Suivi_Infra_2021.git ```

Une fois dans le dossier lancer l'application avec la commande

```
make setup
make start-monitoring-host
make start-monitoring
make start-all
docker-compose.yml
```

Une fois l'application lancée, rendez vous à l'aide de votre navigateur à l'adresse suivante : https://kibana.ledylan.fr pour accéder à Elastic Search.

# Configuration

## Makefile

Tout d'abord pour nous faciliter la tâcher dans la configuration et le déploiement de nos conteneurs il peut être intéressant de créer un fichier Makefile. Ce fichier nous permet de créer des raccourcis pour executer plus rapidement un ensemble de commandes qui seraient fastidieuses. Il permet égalmeent de commettre moins d'erreur, il suffit de le configurer une fois. Il facilitera également le travail des personnes qui utiliseront l'infrastructure. 

Il prend la forme suivante : 


```
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

```

Ici l'ensemble des raccourcis s'executent de la manière suivante. Nous commencons la commande par l'entrée ```make``` auquelle nous rajouterons la commande associée.

Par exemple si je souhaite lancer mon conteneur MongoDB il nous suffira de rentrer la commande

``` make start-mongodb ```


### Les scripts 

Ce Makefile est également associé à deux scripts nous permettant tantôt de nettoyer nos images et tantôt de setup notre configuration

scripts/clean.sh

```
#!/usr/bin/env bash

CONTAINERS=`docker ps | grep metricbeat | awk '{print $1}'`
[ ! -z "${CONTAINERS}" ] && docker rm -f ${CONTAINERS}
echo "All METRICBEAT containers removed !"
docker network rm net 2>&1 > /dev/null || true
exit 0
```

scripts/setup.sh

```
#!/usr/bin/env bash

sudo setfacl -m u:1000:rw /var/run/docker.sock && echo "=> ACLs on /var/run/docker.sock OK"
sudo sysctl -w vm.max_map_count=262144 && echo "=> vm.max_map_count=262144 OK"
docker network create metricbeat || true
docker-compose build
```

Les deux premieres commandes sont necessaires au démarrage de metricbeat et d'Elasticsearch. La commande "docker network" nous permet de créer le réseau metricbeat commun à tous les conteneurs. Et pour finir le script lance le build de l'infrastructure.




## Les conteneurs

Tous d'abord nous allons aborder la configuration des différents conteneurs. Leurs définitions sont réalisés dans un document appelé docker-compose.yml. C'est ce fichier qui est appelé lors des commandes cités précedemment.

Le docker-compose.yml prend la forme suivante : 


```
version: '3'
 
services:
 traefik:
    restart: unless-stopped
    image: traefik:v2.0.2
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
      
    labels:
      - "traefik.http.services.traefik.loadbalancer.server.port=8080"
      - "traefik.http.middlewares.https_redirect.redirectscheme.scheme=https"
      - "traefik.http.middlewares.https_redirect.redirectscheme.permanent=true"
      - "traefik.http.routers.http_catchall.rule=HostRegexp(`{any:.+}`)"
      - "traefik.http.routers.http_catchall.entrypoints=http"
      - "traefik.http.routers.http_catchall.middlewares=https_redirect"
    volumes:
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml
      - ./traefik/tls.yml:/etc/traefik/tls.yml
      - /var/run/docker.sock:/var/run/docker.sock
      - certs:/etc/ssl/traefik
    networks:
      - metricbeat 

 elasticsearch:
   build : ./elasticsearch
   ports: 
    - '9222:9200'
   container_name: metricbeat-elasticsearch
   environment:
     - "discovery.type=single-node"
     - cluster.name=docker-cluster
     - bootstrap.memory_lock=true
     - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
   networks:
     - metricbeat
   volumes:
     - ./config/usr/share/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
     
 kibana:
   build : ./kibana
   container_name: metricbeat-kibana
   ports: 
    - '5666:5601'
   environment:
     SERVER_NAME : kibana
     ELASTICSEARCH_URL : http://elasticsearch:9200
   volumes:
    - ./config/opt/kibana/config/kibana.yml:/opt/kibana/config/kibana.yml:ro
   labels:
     - "traefik.http.routers.blog.tls=true"  
   networks:
     - metricbeat

 metricbeat:
   build: ./metricbeat
   command: -e
   volumes:
     - ./metricbeat/metricbeat.yml:/metricbeat/metricbeat.yml
   depends_on:
     - elasticsearch
   environment:
    - "WAIT_FOR_HOSTS=elasticsearch:9200 kibana:5601"
    - "HOST_ELASTICSEARCH=elasticsearch:9200"
    - "HOST_KIBANA=kibana:5601"
   networks:
    - metricbeat

 metricbeat-host:
   build:
     context: ./metricbeat
     args:
        - METRICBEAT_FILE=metricbeat-host.yml
   container_name: metricbeat-metricbeat-host
   command: -system.hostfs=/hostfs
   volumes:
     - /proc:/hostfs/proc:ro
     - /sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro
     - /:/hostfs:ro
     - /var/run/docker.sock:/var/run/docker.sock
   environment:
     - "WAIT_FOR_HOSTS=elasticsearch:9222 kibana:5666"
     - "HOST_ELASTICSEARCH=elasticsearch:9222"
     - "HOST_KIBANA=kibana:5666"
   extra_hosts:
     - "elasticsearch:172.22.0.1" # The IP of docker0 interface to access host from container
     - "kibana:172.22.0.1" # The IP of docker0 interface to access host from container
   network_mode: host

 reverse-proxy-https-helper:
   image: alpine
   command: sh -c "cd /etc/ssl/traefik
      && wget traefik.me/cert.pem -O cert.pem
      && wget traefik.me/privkey.pem -O privkey.pem"
   volumes:
     - certs:/etc/ssl/traefik

 app:
   container_name: docker-node-mongo
   restart: unless-stopped
   build: ./node
   ports:
     - '3000:3000'
   external_links:
     - mongodb
    networks:
     - mongodb
     
volumes:
   esdata:
     driver: local
   metricbeat-data01:
     driver: local
   certs:

#Réseau commun à tous les conteneurs
networks:
  metricbeat:
    external:
      name: metricbeat

```



## Elastic Search

Le conteneur Elastic Search va permettre de deployer l'application Elastic Search qui nous permettra d'obtenir tous les outils nécessaires au visionnage des métriques.

Le conteneur est défini de la manière suivante : 

```
 elasticsearch:
   build : ./elasticsearch
   ports: 
    - '9222:9200'
   container_name: metricbeat-elasticsearch
   environment:
     - "discovery.type=single-node"
     - cluster.name=docker-cluster
     - bootstrap.memory_lock=true
     - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
   networks:
     - metricbeat
   volumes:
     - ./config/usr/share/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
```

L'image d'Elasticsearch va être cherchée via la commande build dans le DockerFile dédié à ce conteneur. 

elasticsearch/Dockerfile

```FROM docker.elastic.co/elasticsearch/elasticsearch:7.12.1 ```

La commande volumes va nous permettre de transferer la configuration initiale d'Elastic Search dans le conteneur. Le fichier de configuration initiale prend cette forme : 

```
cluster.name: "docker-cluster"
network.host: 0.0.0.0

# minimum_master_nodes need to be explicitly set when bound on a public IP
# set to 1 to allow single node clusters
# Details: https://github.com/elastic/elasticsearch/pull/17288
discovery.zen.minimum_master_nodes: 1
xpack.license.self_generated.type: basic

xpack.security.authc:
  anonymous:
    username: metricbeat_anonymous_user
    roles: superuser
    authz_exception: true
```

Nous définissons le nom du cluster, l'url d'elasisearch, le username de l'utilisateur par défaut  auquel nous n'attachons pas de mot de passe et nous ouvrons l'host à 0.0.0.0 pour autoriser toutes les connexions depuis n'importe quelle IP. Nous lui donnons également les droits de superuser qui s'apparentent à des droits admins.


## Kibana

Le conteneur Kibana permet d'accéder à la suite KIbana qui permet la visualisation des métriques. Il est situé dans le même environnement qu'Elastic Search et est situé dans la même URL. 

```
 kibana:
   build : ./kibana
   container_name: metricbeat-kibana
   ports: 
    - '5666:5601'
   environment:
     SERVER_NAME : kibana
     ELASTICSEARCH_URL : http://elasticsearch:9200
   volumes:
    - ./config/opt/kibana/config/kibana.yml:/opt/kibana/config/kibana.yml:ro
   labels:
     - "traefik.http.routers.blog.tls=true"  
   networks:
     - metricbeat
```

La commande volumes va nous permettre de transferer la cofniguration initiale de Kibana dans le conteneur. Le fichier de configuration initiale prend cette forme : 

```
server.name: kibana
server.host: "0"
elasticsearch.url: http://elasticsearch:9200
elasticsearch.username: metricbeat_anonymous_user
#elasticsearch.password: ""
xpack.monitoring.ui.container.elasticsearch.enabled: true

```
Nous définissons le nom du serveur, l'url d'elasisearch, le username de l'utilisateur par défaut auquel nous n'attachons pas de mot de passe et nous ouvrons l'host à 0.0.0.0 pour autoriser toutes les connexions depuis n'importe quelle IP. 


kibana/Dockerfile

``` FROM docker.elastic.co/kibana/kibana:6.0.0 ```

## Traefik

Le conteneur Traefik va nous permettre de deployer le binaire traefik qui va nous permet de load balancer de manière automique nos conteurs. Ce conteneur se met à jour à chaque fois qu'un conteneur est ajouté ou supprimer depuis le docker-compose.yml. Il va également nous permettre de créer une adresse DNS sur laquelle heberger (localement) notre application. Ici l'url dédié est htpps://kibana.ledylan.fr

Il va également nous permettre de faire des rédirection de ports et d'obtenir un certifcat SSL. Si l'on tente d'accèder à http://kibana.ledylan.fr il nous renverra automatiquement vers https://kibana.ledylan.fr

Ceci étant possible car il écoute aux ports 80 et 443 et l'une de ces missions est la redirection vers le port 443.

Le conteneur est accessible à l'adresse suivante : http//127.0.0.1/80


```
 traefik:
    restart: unless-stopped
    image: traefik:v2.0.2
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
      
    labels:
      - "traefik.http.services.traefik.loadbalancer.server.port=8080"
      - "traefik.http.middlewares.https_redirect.redirectscheme.scheme=https"
      - "traefik.http.middlewares.https_redirect.redirectscheme.permanent=true"
      - "traefik.http.routers.http_catchall.rule=HostRegexp(`{any:.+}`)"
      - "traefik.http.routers.http_catchall.entrypoints=http"
      - "traefik.http.routers.http_catchall.middlewares=https_redirect"
    volumes:
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml
      - ./traefik/tls.yml:/etc/traefik/tls.yml
      - /var/run/docker.sock:/var/run/docker.sock
      - certs:/etc/ssl/traefik
    networks:
      - metricbeat 
```

Les labels nous permettent de configurer notre redirection automatique en https avec la methode appelé Let's Encrypt de Traefik. 

Les volumes vont nous permettre de copier les fichiers traefik.yml + tls.yml dans le conteneur pour faire fonctionner traefik normalement. 


On peut également noter que pour fonctioner Traefik a besoin d'un conteneur qui s'occupera uniquement de récuperer les certificats adéquats sur le site traefik.me pour pouvoir configurer le SSL. Le contenur repose sur une image alpine simple et une suite de commande de récuperation. Une fois récupérer, il renvoit l'entièreté des certificats dans le volume "certs" dédié à cela.


```
reverse-proxy-https-helper:
   image: alpine
   command: sh -c "cd /etc/ssl/traefik
      && wget traefik.me/cert.pem -O cert.pem
      && wget traefik.me/privkey.pem -O privkey.pem"
   volumes:
     - certs:/etc/ssl/traefik
```

## Application Node

Pour récupérer des métriques d'une base données, j'ai décidé de créer une application Node simple, reposant sur le principe d'une "To do list" qui enverra ses données à la base de données mongo. Cette application repose sur 3 fichiers de configurations simples


 1 - node/index.js

```
const express = require('express');
const mongoose = require('mongoose');

const app = express();

app.set('view engine', 'ejs');

app.use(express.urlencoded({ extended: false }));

// Connect to MongoDB
mongoose
  .connect(
    'mongodb://mongo:27017/docker-node-mongo',
    { useNewUrlParser: true }
  )
  .then(() => console.log('MongoDB Connected'))
  .catch(err => console.log(err));

const Item = require('./models/Item');

app.get('/', (req, res) => {
  Item.find()
    .then(items => res.render('index', { items }))
    .catch(err => res.status(404).json({ msg: 'No items found' }));
});

app.post('/item/add', (req, res) => {
  const newItem = new Item({
    name: req.body.name
  });

  newItem.save().then(item => res.redirect('/'));
});

const port = 3000;

app.listen(port, () => console.log('Server running...'));

```

Ce fichier permet de configurer la connexion à la MongoDB localement. Puis s'attèle à definir une fonction "get" et une fonction "post" pour récupérer et rentrer les données saisies dans l'application dans la Mongo.

Dans ce fichier nous définissons également le port sur lequel le serveur node écoutera, ici le port 3000. Et nous créeons également un lien vers le visuel de l'application situé dans le fichier views/index.ejs


 2 - views/index.ejs 
 
 Ce fichier est codé en ejs pour sa simplicité d'écriture. Il prend la forme suivante
 
 ```
 <!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="ie=edge">
  <title>My Node App</title>
</head>

<body>
  <h1>My Node App</h1>
  <form method="post" action="/item/add">
    <label for="name">Name</label>
    <input type="text" name="name">
    <input type="submit" value="Add">
  </form>
  <h4>Items:</h4>
  <ul>
    <% items.forEach(function(item) { %>
      <li>
        <%= item.name %>
      </li>
      <% }); %>
  </ul>
</body>

</html>
 
 ```

La vue de notre application vient tout simplement récupérer les données de la class Items que nous expliquerons par la suite. Elle permet donc la récupération des données et la possibilité de rentrer de nouveaux inputs en base de données. 


3- models/Items.js

Ce fichier nous permet de créer un schéma simple pour pouvoir saisir des entrées en base de données. Deux entrées sont configurées. 

L'entrée "name" est une string permettant de contenir le texte saisi. L'entrée "date" nous permet de saisir l'heure à laquelle a été saisie le message. 

```
const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const ItemSchema = new Schema({
  name: {
    type: String,
    required: true
  },
  date: {
    type: Date,
    default: Date.now
  }
});

module.exports = Item = mongoose.model('item', ItemSchema);

```


4- Le conteneur

Une fois l'application codée, il nous faut créer un conteneur pour pouvoir la lancer. 

Le conteneur écoute sur le port 3000 (le port 80 étant déjà occupé). Nous créeons également un lien vers notre conteneur mongo graĉe à la commande "external_links"

Le "build ." permet d'aller récuperer le Dockerfile et de build le conteneur grâce à lui

```

 app:
    container_name: docker-node-mongo
    restart: unless-stopped
    build: ./node
    ports:
      - '3000:3000'
    external_links:
      - mongodb
```

Le "build " permet d'aller récuperer le Dockerfile et de build le conteneur grâce à lui

Le Dockerfile prend la forme suivante :

```
FROM node:10

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
```

Il récupérer l'image officielle node:10, créer un espace de travail, copie le package.json et lance la commande npm install qui permet de telecharger les nodes modules qui feront tourner l'application. Il ouvre le port 3000 et lance la commande ```npm start``` qui permet de lancer l'appplciation node. 


## MongoDB

Le conteneur MongoDB va nous permettre de créer un sevreur de base de données Mongo qui va pouvoir stocker localement et avec persistance les données saisies dans l'application Node. Il est défini dans le fichier docker-compose.mongodb.yml pour pouvoir éviter les erreurs de créations de subnet, pour repsecter les bonnes pratiques Docker ainsi que pour l'appeler plus aisément.  

Il prend la forme suivante : 

```
   
version: "2.2"
services:

  mongodb:
    image: mongo:3.5.13-jessie
    container_name: metricbeat-mongodb
    networks:
      - mongodb

networks:
  mongodb:
    external:
      name: metricbeat
```

Nous récupérons l'image docker mongo et nous ouvrons le port 27017 qui est le port naturel de Mongo. Nous créeons un sous réseau appelé mongodb qui est associé au réseau principal nommé Metribeat dont tous les conteneurs principaux dépendent. 


## Metricbeat

Le conteneur Metricbeat nous permet de récupérer et de renvoyer des métriques à Kibana. 

La configuration prend la forme suivante :

```
 metricbeat:
   build: ./metricbeat
   command: -e
   volumes:
     - ./metricbeat/metricbeat.yml:/metricbeat/metricbeat.yml
   depends_on:
     - elasticsearch
   environment:
    - "WAIT_FOR_HOSTS=elasticsearch:9200 kibana:5601"
    - "HOST_ELASTICSEARCH=elasticsearch:9200"
    - "HOST_KIBANA=kibana:5601"
   networks:
    - metricbeat

 metricbeat-host:
   build:
     context: ./metricbeat
     args:
        - METRICBEAT_FILE=metricbeat-host.yml
   container_name: metricbeat-metricbeat-host
   command: -system.hostfs=/hostfs
   volumes:
     - /proc:/hostfs/proc:ro
     - /sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro
     - /:/hostfs:ro
     - /var/run/docker.sock:/var/run/docker.sock
   environment:
     - "WAIT_FOR_HOSTS=elasticsearch:9222 kibana:5666"
     - "HOST_ELASTICSEARCH=elasticsearch:9222"
     - "HOST_KIBANA=kibana:5666"
   extra_hosts:
     - "elasticsearch:172.22.0.1"
     - "kibana:172.22.0.1" 
   network_mode: host
```

Metricbeat a besoin de deux conteneur pour fonctionner. 

Le premier conteneur appelé "metricbeat" permet de lancer metricbeat et nous permettra de récuper les métriques MongoDB. Il depend d'ElastiSearch et a besoin que les conteneurs Elasticsearch et Kibana soient lancés pour pouvoir s'y connecter. 

La commande volume va nous permettre de renvoyer la configuration des modules de metricbeat dans son conteneur. La confiration prend la forme suivante : 

```
metricbeat.modules:

#------------------------------- MongoDB Module -------------------------------

- module: mongodb
  enabled: true
  metricsets: ["dbstats", "status"]
  period: 5s
  hosts: ["mongodb:27017"]

#-------------------------- Elasticsearch output ------------------------------
output.elasticsearch:
  username: "metricbeat_anonymous_user"
  #password: ""
  hosts: ["${HOST_ELASTICSEARCH}"]

setup.kibana:
  host: "${HOST_KIBANA}"

#============================== Dashboards =====================================
# These settings control loading the sample dashboards to the Kibana index. Loading
# the dashboards is disabled by default and can be enabled either by setting the
# options here, or by using the `-setup` CLI flag.
setup.dashboards.enabled: true

logging.level: warning
logging.to_files: true
logging.to_syslog: false
logging.files:
  path: /var/log/metricbeat
  name: metricbeat.log
  keepfiles: 2
  permissions: 0644
  
````

Il nous permet de déclarer le module mongodb et donc d'indiquer les métriques que nous souhaitons récupérer ainsi que l'host de la base de données. Mais également de lui indiquer les hosts kibana et elasticsearch que nous avons pu lui donner lors de sa configuration avec la commande environnement. Il nous permet également d'envoyer tous les dashboards associés à Kibana qui nous permettront une visualisation graphique des données receuillies.


Le second conteneur appelé "metricbeat-host" va nous permettre de monitorer nos hosts : ElasticSearch et Kibana mais également de pouvoir récuperer des métriques Docker concernant nos conteneurs. Il va aussi nous permettre d'accèder directement à Kibana depuis les conteneurs via la commande extra_hosts qui indiques les adresses IP de chacun des conteneurs. Tout comme le premier nous allons pouvoir donner sa configuraiton à son conteneur 

La configuration prend la forme suivante : 

```
metricbeat.modules:

#------------------------------- System Module -------------------------------
- module: system
  metricsets: ["cpu", "load", "filesystem", "fsstat", "memory", "network", "process", "core", "diskio", "socket"]
  period: 5s
  enabled: true
  processes: ['.*']

  cpu.metrics:  ["percentages"]
  core.metrics: ["percentages"]

#------------------------------- Docker Module -------------------------------
- module: docker
  metricsets: ["container", "cpu", "diskio", "healthcheck", "info", "memory", "network"]
  hosts: ["unix:///var/run/docker.sock"]
  enabled: true
  period: 5s

#-------------------------- Elasticsearch output ------------------------------
output.elasticsearch:
  #username: "metricbeat_anonymous_user"
  #password: ""
  hosts: ["${HOST_ELASTICSEARCH}"]

setup.kibana:
  host: "${HOST_KIBANA}"

#============================== Dashboards =====================================
# These settings control loading the sample dashboards to the Kibana index. Loading
# the dashboards is disabled by default and can be enabled either by setting the
# options here, or by using the `-setup` CLI flag.
setup.dashboards.enabled: true

logging.level: warning
logging.to_files: true
logging.to_syslog: false
logging.files:
  path: /var/log/metricbeat
  name: metricbeat.log
  keepfiles: 2
  permissions: 0644

```
Ce fichier reprend le même principe que le précedent, nous indiquons les métriques system et Docker que nous souhaitons. Il nous permet également d'envoyer tous les dashboards associés à Kibana qui nous permettront une visualisation graphique des données receuillies.


metricbeat/entrypoint.sh

Ce script va nous permettre de mieux visualiser la bonne connexion de notre conteneur à ElastiSaerch et Kibana.

```
#!/usr/bin/env bash

wait_single_host() {
  local host=$1
  shift
  local port=$1
  shift

  echo "==> Check host ${host}:${port}"
  while ! nc ${host} ${port} > /dev/null 2>&1 < /dev/null; do echo "   --> Waiting for ${host}:${port}" && sleep 1; done;
}

wait_all_hosts() {
  if [ ! -z "$WAIT_FOR_HOSTS" ]; then
    local separator=':'
    for _HOST in $WAIT_FOR_HOSTS ; do
        IFS="${separator}" read -ra _HOST_PARTS <<< "$_HOST"
        wait_single_host "${_HOST_PARTS[0]}" "${_HOST_PARTS[1]}"
    done
  else
    echo "IMPORTANT : Waiting for nothing because no $WAIT_FOR_HOSTS env var defined !!!"
  fi
}

wait_all_hosts

while ! curl -s -X GET ${HOST_ELASTICSEARCH}/_cluster/health\?wait_for_status\=yellow\&timeout\=60s | grep -q '"status":"yellow"'
do
    echo "==> Waiting for cluster YELLOW status" && sleep 1
done

echo ""
echo "Cluster is YELLOW"
echo ""


bash -c "/usr/local/bin/docker-entrypoint $*"
```






