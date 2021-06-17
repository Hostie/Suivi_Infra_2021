# Suivi_Infra_2021

# Projet 

Le projet consiste en une infrastructure conteneurisée permettant la récupération de métriques d'une API. Elle repose sur la technologie Docker et sur différentes technologies : Traeffik, Elastic Search, Kibana, Node et Metricbeat

# Pré-requis

- Ubuntu 20.04 LTS
- Docker
- Github


# Lancement de l'infrastructure 

Après avoir intaller le binaire Docker sur votre machine (https://docs.docker.com/engine/install/ubuntu/), clonez le projet sur votre machine. 

Une fois dans le dossier lancer l'application avec la commande

```
docker-compose build
docker-compose up 
```

Une fois l'application lancée, rendez vous à l'aide de votre navigateur à l'adresse suivante : https://kibana.ledylan.fr pour accéder à Elastic Search.


# Configuration

Tous d'abord nous allons aborder la configuration des différents conteneurs. Leur définition est réalisé dans un document appelé docker-compose.yml. C'est ce fichier qui est appelé lors du ```docker-compose up```.

Le docker-compose.yml prend la forme suivante : 


```


```



## Elastic Search

Le conteneur Elastic Search va permettre de deployer l'application Elastic Search qui nous permettra d'obtenir tous les outils nécessaires au visionnage des métriques. Il écoute aau port 9200

Le conteneur est défini de la manière suivante : 

```
 elasticsearch:
   build : ./elasticsearch
   container_name: elasticsearch
   environment:
     - "discovery.type=single-node"
   networks:
     - net
   volumes:
     - esdata:/usr/share/elasticsearch/data 
```

L'image d'Elasticsearch va être cherché via la commande build dans le DockerFile dédié à ce conteneur :

elasticsearch/Dockerfile

```FROM docker.elastic.co/elasticsearch/elasticsearch:7.12.1 ```

Nous allons également prevoir un volume pour stocker les datas d'ElasticSearch dans le conteneur;


## Kibana

Le conteneur Kibana permet d'accéder à la suite KIbana qui permet la visualisation des métriques. Il est situé dans le même environnement qu'Elastic Search et est situé dans la même URL. 

```
 kibana:
   build : ./kibana
   container_name: kibana
   environment:
     SERVER_NAME : kibana
     ELASTICSEARCH_URL : http://elasticsearch:9200
   labels:
     - "traefik.http.routers.blog.tls=true"  
   networks:
     - net
```

Le build de l'image se fait de la même manière qu'Elastic Search via le Dockerfile dédié.

kibana/Dockerfile

``` FROM docker.elastic.co/kibana/kibana:7.12.0 ```

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
      - ./traefik.yml:/etc/traefik/traefik.yml
      - ./tls.yml:/etc/traefik/tls.yml
      - /var/run/docker.sock:/var/run/docker.sock
      - certs:/etc/ssl/traefik
    networks:
      - net 
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
