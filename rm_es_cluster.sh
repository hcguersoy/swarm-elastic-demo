#! /usr/bin/env bash

# A small script to remove the es cluster containers together with its 
# consul instance

DOCKER=/usr/local/bin/docker
DOCKER_MACHINE=/usr/local/bin/docker-machine
DOCKER_COMPOSE=/usr/local/bin/docker-compose
DOCKER_COMPOSE_FILE=./docker-compose-elastic.yml

# set docker host coordinates correctly
eval $($DOCKER_MACHINE env --swarm swarm-1)

$DOCKER_COMPOSE -f ${DOCKER_COMPOSE_FILE} -p elastic down

echo "Finished."