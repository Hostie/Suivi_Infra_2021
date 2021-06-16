# Suivi_Infra_2021

#Projet 

Le projet consiste en une infrastructure conteneurisée permettant la récupération de métriques d'une API. Elle repose sur la technologie Docker et sur différentes technologies : Traeffik, Elastic Search, Kibana, Node et Metricbeat

#Pré-requis

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



#Configuration


