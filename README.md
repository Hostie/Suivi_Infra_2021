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

## Application Node

Pour récupérer des métriques d'une base données, j'ai décidé de créer une application Node simple, reposant sur le principe d'une "To do list" qui enverra ses données à la base de données mongo. Cette application repose sur 3 fichiers de configurations simples


 1 - index.js

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
    build: .
    ports:
      - '3000:3000'
    external_links:
      - mongo
```

Le "build ." permet d'aller récuperer le Dockerfile et de build le conteneur grâce à lui

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

Le conteneur MongoDB va nous permettre de créer un sevreur de base de données Mongo qui va pouvoir stocker localement et avec persistance les données saisies dans l'application Node.

Il prend la forme suivante : 

```
 mongo:
    container_name: mongo
    image: mongo
    ports:
      - '27017:27017'
```

Nous récupérons l'image docker mongo et nous ouvrons le port 27017 qui est le port naturel de Mongo. 



