#! /usr/bin/env bash

DOCKER=/usr/local/bin/docker
DOCKER_MACHINE=/usr/local/bin/docker-machine

echo "Setting up docker environment to connect to swarm..."
# set docker host coordinates correctly
eval $($DOCKER_MACHINE env --swarm swarm-1)

echo "Retrieving information about elasticsearch node elastic_esnode_1..."
ES1_NODE=$(docker inspect --format='{{.Node.IP}}' elastic_esnode_1)
ES1_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "9200/tcp") 0).HostPort}}' elastic_esnode_1)

echo "Downloading test data to node swarm-1..."
$DOCKER_MACHINE ssh swarm-1 "wget https://www.elastic.co/guide/en/kibana/3.0/snippets/shakespeare.json"

echo "Uploading the testdata on swarm node swarm-1 into elasticsearch node es-1..."

$DOCKER_MACHINE ssh swarm-1 curl -s -XPOST http://$ES1_NODE:$ES1_PORT/_bulk --data-binary @shakespeare.json >/dev/null 2>&1

echo "Finished importing test data!"