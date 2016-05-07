# Simple Docker Swarm Demo with Elasticsearch

In this very simple Docker Swarm Demo we create Docker hosts with Docker Machine and install after this a small Elasticsearch cluster using Docker Compose.

**Attention:** Please be aware that I don't configure any Firewall or something else. After the installation of the Elasticsearch cluster it can be accessed by anyone in the whole Galaxy and beyond who knows the IP and Port. May you'll bet with your friends how long it will take before it is captured or the Vogons are alerted.

This is (still) a pure airport hack. Please don't make me responsible if something goes wrong. 

Suggestions are always welcome.

# Thanks too...
This demo was inspired by a Gist from [Thomas Barlow](https://github.com/tombee) and thanks to [Chris Wendt](https://github.com/chrismwendt) for the nice [Elasticsearch SRV plugin](https://github.com/github/elasticsearch-srv-discovery). 

# Prerequisites
This version of the demo is tested with

* Docker 1.11.1
* Docker Machine 0.7.0
* Docker Swarm 1.2.2-rc1    

# Creating Swarm Cluster

**Hint:**
If you're running on *boot2docker* (VirtualBox) you have to change some parameters in the shell scripts, especially the parameter for the interface name. I usually use Digital Ocean for this kind of demos.

Creating the Swarm cluster is done by calling the shell script `create_swarm.sh`. Please check the variables, inline comments and path to the docker binaries. 
On OS X or Windows you should install the latest Docker Toolbox or install manually the binaries.

In addition, you need, if you don't change the settings to use boot2docker / VirtualBox, a DigitalOcean API token. If you don't have a DO account already you can contact me for a $10 promo code.

The `create_swarm.sh` script needs several minutes, depending on the load on Digital Ocean. I useally use the datacenters `ams3` or `fra1`.

```
$ ./create_swarm.sh
==> Create a node for consul...
Running pre-create checks...
Creating machine...
(consul) Creating SSH key...
(consul) Creating Digital Ocean droplet...
(consul) Waiting for IP address to be assigned to the Droplet...
<snip/snap>
==> set the docker coordinates
==> Creating overlay network
7356607768c67a4705c4f33f58edb5551fddf6bc64748393e0aa4020338b5a86
Access to Consul (SWARM) UI via http://46.101.235.131:8500/ui
 **** Finished creating VMs and setting up Docker Swarm ****  
```

After this, you should have your docker machines running:

```
docker-machine ls
NAME      ACTIVE   DRIVER         STATE     URL                         SWARM
consul    -        digitalocean   Running   tcp://46.101.221.120:2376   
default   -        virtualbox     Stopped                               
swarm-1   -        digitalocean   Running   tcp://46.101.214.170:2376   swarm-1 (master)
swarm-2   -        digitalocean   Running   tcp://46.101.174.160:2376   swarm-1
swarm-3   -        digitalocean   Running   tcp://46.101.237.141:2376   swarm-1
swarm-4   -        digitalocean   Running   tcp://46.101.134.14:2376    swarm-1
```

And the overlay network called *multihost* should be available, too:

```
$ eval $(docker-machine env --swarm swarm-1)
$ docker network ls
NETWORK ID          NAME                DRIVER
368838aacf1e        multihost           overlay          
(... some more)
```

Now you should be able to create containers and test if they can communicate with each other. Press `ctrl-c` to stop the ping process.

```
$ docker run -d --name="long-running" \
              --net="multihost" \
              --env="constraint:node==swarm-1" \
              busybox top
$ docker run -it \
             --rm \
             --env="constraint:node==swarm-2" \
             --net="multihost" \
             busybox ping long-running
PING long-running (10.0.0.2): 56 data bytes
64 bytes from 10.0.0.2: seq=0 ttl=64 time=1.114 ms
64 bytes from 10.0.0.2: seq=1 ttl=64 time=0.675 ms
64 bytes from 10.0.0.2: seq=2 ttl=64 time=0.689 ms
64 bytes from 10.0.0.2: seq=3 ttl=64 time=0.768 ms
64 bytes from 10.0.0.2: seq=4 ttl=64 time=1.014 ms
64 bytes from 10.0.0.2: seq=5 ttl=64 time=0.700 ms
64 bytes from 10.0.0.2: seq=6 ttl=64 time=0.733 ms
^C
--- long-running ping statistics ---
7 packets transmitted, 7 packets received, 0% packet loss
round-trip min/avg/max = 0.675/0.813/1.114 ms              
```

Now you can remove the container `long-running`:

```
$ docker rm -f long-running
```

BTW, you can connect your consul with this URL:
http://[IP of machine consul]:8500/ui/.
To get the IP of the consul machine simply use `docker-machine ip consul`.

Now, lets play with Elasticsearch.

# Creating the Elasticsearch cluster
**Attention:** You should never, **never** use this setup for a productive environment. You're warned!

Again, we can do this task with a small shell script called `es_cluster.sh` which itself uses Docker Compose. This will create 8 Elasticsearch containers (see the variable `AMOUNT_ADDITIONAL_NODES`) and the data will be splitted into 8 shards and replicated 8 times (this is a setup which you really not use in a production environment). In addition, in the compose file `docker-compose-elastic.yml` a Consul service is defined which is needed for the discovery.
You can change the amount of elasticsearch nodes, replicas and shards in the script. The used Elasticsearch version is currently 1.7.3 due to the incompatibility of Bigdesk with current Elasticsearch 2.x.
This script installs several Elasticsearch Plugins, too:

* BigDesk ([Homepage](http://bigdesk.org))
* Paramedic ([Homepage](https://github.com/karmi/elasticsearch-paramedic))
* elasticsearch-srv-discovery ([Homepage](https://github.com/github/elasticsearch-srv-discovery)) 

The `elasticsearch-srv-discovery` plugin is used to retrieve the coordinates of all already provisioned elasticsearch nodes from Consul (which is created by Docker Compose, too), using it as a service discovery system. The nodes register themselve using the Consul REST API (take a look at the `command` part for the `elastic`-Service. The plugin itself uses DNS SRV requests (see [RFC 2782](https://tools.ietf.org/html/rfc2782)) to retrieve the data from Consul. In our case, we tell the plugin to use TCP because UDP requests will return only three results and may result in seperated clusters (even the probability is realy low). 

Now, lets start the Elasticsearch cluster:

```
$ ./es_cluster.sh
./es_cluster.sh 
Starting Consul...
Creating network "elastic_elasticnet" with driver "overlay"
Pulling consul (gliderlabs/consul-server:latest)...
<snip/snap>
Connect to BigDesk with:     http://46.101.221.247:32769/_plugin/bigdesk/
Connect to Paramedic with:   http://46.101.221.247:32769/_plugin/paramedic/
Access to Discovery Consul UI via http://46.101.216.246:8500/ui
Finished
```

You can list your running containers with the help of Docker Compose:
```
docker-compose -f ./docker-compose-elastic.yml -p elastic ps
```

Now the elasticsearch cluster is ready to index data.
For your convenience, there is already a small shell script, too: `import-testdata.sh`.
This script downloads a JSON file with test data from Elasticsearch into the Docker node swarm-1 and imports the data into elasticsearch, using the bulk import REST interface on elasticsearch node es-1.


```
$ ./import-testdata.sh
Setting up docker environment to connect to swarm...
Retrieving information about elasticsearch node elastic_esnode_1...
Downloading test data to node swarm-1...
...
Uploading the testdata on swarm node swarm-1 into elasticsearch node elastic_esnode_1...
Finished importing test data!
#
```

# Deprovision

Use the script `rm-swarm.sh` to remove all created Docker machines but take care about that you have configured in the script the same amount of nodes as in the create script.

In addition, you can use the script `rm_es_cluster.sh` to remove only the elasticsearch containers and deregister them.

# TODO
* Show resheduling of containers with Docker Swarm (have to wait for [SWARM #2149](https://github.com/docker/swarm/issues/2149) and [SWARM #2133](https://github.com/docker/swarm/issues/2133))

# License

Apache License, Version 2.0 

# The End
That's all, folks. 








