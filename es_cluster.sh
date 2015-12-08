#! /usr/bin/env bash

# This script creates a small elastic cluster.
# The amount of es nodes can be changed using the 
# variable AMOUNT_NODES

DOCKER=/usr/local/bin/docker
DOCKER_MACHINE=/usr/local/bin/docker-machine

# Memory constraint for the container.
# This doesn't change anything on the JVM settings...
# and you shouldn't use this setting in a (near) production environment
ES_MAXMEM=512m

# How many es nodes should be started?
AMOUNT_NODES=9

# How many es shards?
AMOUNT_SHARDS=8

# How many replicas for each shard?
# we just create many replicas to visualize them on BigDesk
AMOUNT_REPLICAS=8

# The image to use in this test.
# If you wan't to use a 2.x image BigDesk will not run
ELASTIC_IMAGE="elasticsearch:1.7.3"

# The BigDesk Version
BIGDESK_VERSION=2.5.0

# The elasticsearch-srv-discovery plugin version
# For TCP support, you need at least 1.5.1
SRV_DISCOVERY_VERSION=1.5.1

# and the cluster name
CLUSTER_NAME=swarmones

# Consul DNS UDP Port
CONSUL_PORT_UDP=8600
#... and TCP 
CONSUL_PORT_TCP=8653

# which port should be used?
CONSUL_PORT=$CONSUL_PORT_TCP

#SRV Protocol, either tcp or udp
SRV_PROTOCOL="tcp"
# SRV_PROTOCOL="udp"

# set docker host coordinates correctly
eval $($DOCKER_MACHINE env --swarm swarm-1)

if [ -z "${DOCKER_HOST}" ]; then
  echo "It looks like the environment variable DOCKER_HOST has not"
  echo "been set.  The elasticsearch cluster cannot be started unless this has"
  echo "been set appropriately. "
  exit 1
fi

# pull elasticsearch image
echo "Pulling image $ELASTIC_IMAGE"
$DOCKER pull $ELASTIC_IMAGE

# getting consul IP
echo "Retrieving Consul IP..."
CONSUL_IP=$(docker-machine ip consul)
echo "Consul IP is $CONSUL_IP"

#At which level discovery should log
DISCOVERY_LOGLEVEL=TRACE

# here we start the es nodes
# we suppose that the multihost network uses the 10.0.0.x IP range
# and set the first instance IPs as the seed nodes for the es cluster
# this can be done in a more better way with Consul or etcd ;-)
for ((node=1; node<=$AMOUNT_NODES; node++))
do
    echo "Sending request to create es-$node now..."
    $DOCKER run -d \
            --name "es-$node" \
            -P \
            --net="multihost" \
            --memory=$ES_MAXMEM \
            --memory-swappiness=0 \
            --restart=unless-stopped \
            $ELASTIC_IMAGE \
            /bin/bash -c "plugin install srv-discovery --url https://github.com/github/elasticsearch-srv-discovery/releases/download/${SRV_DISCOVERY_VERSION}/elasticsearch-srv-discovery-${SRV_DISCOVERY_VERSION}.zip
            elasticsearch -Des.node.name=es-$node \
                          -Des.cluster.name=$CLUSTER_NAME \
                          -Des.network.host=0.0.0.0 \
                          -Des.index.number_of_shards=$AMOUNT_SHARDS \
                          -Des.index.number_of_replicas=$AMOUNT_REPLICAS \
                          -Des.discovery.zen.ping.multicast.enabled=false \
                          -Des.discovery.type=srv \
                          -Des.discovery.srv.query=elastic.service.consul \
                          -Des.discovery.srv.servers=${CONSUL_IP}:${CONSUL_PORT} \
                          -Des.discovery.srv.protocol=${SRV_PROTOCOL} \
                          -Des.logger.discovery=${DISCOVERY_LOGLEVEL}"

    # may you've to change here the interface from eth0 to eth1 on boot2docker
    ES_IP=$(docker exec es-${node} ip addr | awk '/inet/ && /eth0/{sub(/\/.*$/,"",$2); print $2}')
    echo "IP of es-${node} is ${ES_IP}"
    
    echo "Registering node in Consul"
    curl -X PUT \
      -d "{\"Node\": \"es-${node}\", \"Address\": \"${ES_IP}\", \"Service\": {\"ID\": \"elastic-${node}\", \"Service\": \"elastic\", \"ServiceAddress\": \"${ES_IP}\", \"Port\": 9300}}" \
      http://${CONSUL_IP}:8500/v1/catalog/register
    echo ""

    if [ $node -eq 1 ]
    then
        echo "Installing bigdesk"
        $DOCKER exec es-$node plugin install lukas-vlcek/bigdesk/$BIGDESK_VERSION
        echo "Installing paramedic"
        $DOCKER exec es-$node plugin install karmi/elasticsearch-paramedic
    fi
done

ES1_NODE=$(docker inspect --format='{{.Node.IP}}' es-1)
ES1_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "9200/tcp") 0).HostPort}}' es-1)

echo "Connect to BigDesk with:     http://$ES1_NODE:$ES1_PORT/_plugin/bigdesk/"
echo "Connect to Paramedic with:   http://$ES1_NODE:$ES1_PORT/_plugin/paramedic/"

echo "Finished"
