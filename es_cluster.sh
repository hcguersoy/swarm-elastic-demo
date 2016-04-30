#! /usr/bin/env bash

DOCKER=/usr/local/bin/docker
DOCKER_MACHINE=/usr/local/bin/docker-machine
DOCKER_COMPOSE=/usr/local/bin/docker-compose
DOCKER_COMPOSE_FILE=./docker-compose-elastic.yml

# How many additional es nodes should be started?
AMOUNT_ADDITIONAL_NODES=3


# The image to use in this test.
# If you wan't to use a 2.x image BigDesk will not run
export ELASTIC_IMAGE="elasticsearch:1.7.3"
export SRV_DISCOVERY_VERSION=1.5.1

export SRV_DISCOVERY_QUERY=elastic.service.consul

# set docker host coordinates correctly
eval $($DOCKER_MACHINE env --swarm swarm-1)

if [ -z "${DOCKER_HOST}" ]; then
  echo "It looks like the environment variable DOCKER_HOST has not"
  echo "been set.  The elasticsearch cluster cannot be started unless this has"
  echo "been set appropriately. "
  exit 1
fi

echo "Starting Consul..."

# this should start an initial node with consul 
$DOCKER_COMPOSE -f ${DOCKER_COMPOSE_FILE} -p elastic up -d consul

echo "Give Consul time to finish start up..."
sleep 15

echo "Starting elasticsearch nodes..."
#now we start and scale 
$DOCKER_COMPOSE -f ${DOCKER_COMPOSE_FILE} -p elastic scale esnode=$AMOUNT_ADDITIONAL_NODES

ES1_NODE=$(docker inspect --format='{{.Node.IP}}' elastic_esnode_1)
ES1_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "9200/tcp") 0).HostPort}}' elastic_esnode_1)

CONSUL_IP=$(docker inspect --format='{{.Node.IP}}' discoverer)
CONSUL_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "8500/tcp") 0).HostPort}}' discoverer)

echo "Current DNS entries in Consul:"
dig @${CONSUL_IP} -p 8600 ${SRV_DISCOVERY_QUERY} +tcp SRV

echo "Connect to BigDesk with:     http://$ES1_NODE:$ES1_PORT/_plugin/bigdesk/"
echo "Connect to Paramedic with:   http://$ES1_NODE:$ES1_PORT/_plugin/paramedic/"

echo "Access to Discovery Consul UI via http://${CONSUL_IP}:8500/ui"

echo "Finished"
