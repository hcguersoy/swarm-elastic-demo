# A simple script to create a Docker Swarm Cluster with Docker Overlay Networking.
# Inspired by https://gist.github.com/tombee/7a6bb29219bddebb9602
# If you use please set the environment variable DIGITAL_OCEAN_TOKEN with your 
# DO token which you can retrieve from the settings page.

DOCKER=/usr/local/bin/docker
DOCKER_MACHINE=/usr/local/bin/docker-machine

# possible regions for DigitalOcean... fra1, ams1..ams3, lon1, nyc1..nyc3 and more
DIGITAL_OCEAN_REGION=fra1

# possible: ubuntu-15-04-x64, ubuntu-15-10-x64, debian-8-x64
# be arware that you need Kernel >= 3.16, so Ubuntu 14.04 will not work due to Kernel
# and 15.x will not work because the Docker installation scripts don't support them yet
DIGITAL_OCEAN_IMAGE=debian-8-x64

# If you want to use a specfic boot2docker image use this
BOOT2DOCKER_IMAGE="file:///mydirectory/my_own_boot2docker.iso"

# How many Swarm nodes (incl. Swarm master)?
AMMOUNT_NODES=4

# This VM memory setting applies on DO
# Please check the available sizes for your region on the DO documentation
SWARM_NODE_MEMORY=2gb

# ... and this on VB, ammount is in MB
VB_DEFAULT_MEM=512

# If you wan't to install a Docker RC use this URL instead
# DOCKER_INSTALL_URL="https://test.docker.com"
DOCKER_INSTALL_URL="https://get.docker.com"

# You have to advertise the public interface of the VM
# On DO, this normally is eth0 (Ubuntu, Debian), on VB it is eth1 (boot2docker)
BIND_INTERFACE=eth0

# which Swarm version has to be installed?
# Check the Swarm releases page on Github ()
SWARM_IMAGE="swarm:1.0.0"

# use this with virtualbox if you use your own boot2docker image and comment out the next line
# DRIVER_SPECIFIC_VB="--driver virtualbox --virtualbox-boot2docker-url=$BOOT2DOCKER_IMAGE --virtualbox-memory=$VB_DEFAULT_MEM"
DRIVER_SPECIFIC_VB="--driver virtualbox --virtualbox-memory=$VB_DEFAULT_MEM"

# This is for DigitalOcean. Don't forget to set DIGITAL_OCEAN_TOKEN
DRIVER_SPECIFIC_DO="--driver digitalocean --digitalocean-access-token=$DIGITAL_OCEAN_TOKEN --digitalocean-region=$DIGITAL_OCEAN_REGION --digitalocean-size=$SWARM_NODE_MEMORY --digitalocean-image=$DIGITAL_OCEAN_IMAGE"

# Do you wan't to use Boot2Docker/VB or DigitalOcean?
DRIVER_DEFINITION=$DRIVER_SPECIFIC_DO
# DRIVER_DEFINITION=$DRIVER_SPECIFIC_VB

# create a node for consul, name it consul
echo "==> Create a node for consul..."
docker-machine create \
    $DRIVER_DEFINITION \
    --engine-install-url=$DOCKER_INSTALL_URL \
    consul || { echo 'Creation of Consul node failed' ; exit 1; }

echo "==> Installing and starting consul on that server"
$DOCKER $(docker-machine config consul) run \
                                       -d \
                                       -p 8500:8500 \
                                       -p 8400:8400 \
                                       -p 8600:53/udp \
                                       -h consul \
                                       progrium/consul -server -bootstrap-expect 1 -ui-dir /ui \
                                       || { echo 'Installation of Consul failed' ; exit 1; }

echo "==> Creating a node for swarm master and starting it..."
docker-machine create \
    $DRIVER_DEFINITION \
    --engine-install-url=$DOCKER_INSTALL_URL \
    --swarm \
    --swarm-image=$SWARM_IMAGE \
    --swarm-master \
    --swarm-discovery="consul://$(docker-machine ip consul):8500" \
    --engine-opt="cluster-advertise=$BIND_INTERFACE:2376" \
    --engine-opt="cluster-store=consul://$(docker-machine ip consul):8500" \
    swarm-1 || { echo 'Creation of Swarm Manager Node failed' ; exit 1; }

echo "==> Creating now all other nodes in parallel ..."
for ((node=2; node<=$AMMOUNT_NODES; node++))
do
    echo "Sending request to create node-$node now"
    $DOCKER_MACHINE create \
        $DRIVER_DEFINITION \
        --engine-install-url=$DOCKER_INSTALL_URL \
        --swarm \
        --swarm-image=$SWARM_IMAGE \
        --swarm-discovery="consul://$(docker-machine ip consul):8500" \
        --engine-opt="cluster-advertise=$BIND_INTERFACE:2376" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul):8500" \
        swarm-$node &
done

# wait until all nodes have been created
wait

echo "Creating overlay network"
eval $(docker-machine env --swarm swarm-1)
$DOCKER network create -d overlay multihost

echo " **** Finished creating VMs and setting up Docker Swarm ****  "

