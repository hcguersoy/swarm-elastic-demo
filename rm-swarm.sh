#! /bin/bash

# Clean up Docker Machine VMs

DOCKER_MACHINE=/usr/local/bin/docker-machine
AMMOUNT_NODES=4

echo "Removing consul"
$DOCKER_MACHINE rm -y consul &
for ((node=1; node<=$AMMOUNT_NODES; node++))
do
    echo "Removing node-$node now"
    $DOCKER_MACHINE rm -y swarm-$node &
done
wait

$DOCKER_MACHINE ls
echo "Finished removing all VMs"
