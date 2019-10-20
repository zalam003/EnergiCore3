<h1>WORK IN PROGRESS - NOT FOR RELEASE</H1>
<H1>NRG Virtual Machine</H1>
This directory contains information on how to run Energi Core Node on a Docker container.<br>
<p>
<H2>Get Docker Engine - Community for Ubuntu</H2>
Go to the following link for details of installing Docker Community Edition:

```
https://docs.docker.com/install/linux/docker-ce/ubuntu/
```

Once Docker CE is verified, download <b>Dockerfile</b> and run to build the Docker image:

```
docker build -t energi3-testnet .
```

Start energi3-testnet:

```
docker run energi3-testnet
```

<h1>Quickstart</h1>
<h2>Get docker image</h2>
You might take either way:

<h3>Pull a image from Public Docker hub</h3>
```
$ docker pull energi3/energi3
```
<h3>Or, build energi3 image with provided Dockerfile</h3>
```
$docker build --rm -t energi3/energi3 .
```
For historical versions, please visit docker hub

<h3>Prepare data path and energi3.conf</h3>
In order to use user-defined config file, as well as save block chain data, -v option for docker is recommended.

First chose a path to save energi3 block chain data:
```
sudo rm -rf /data/energi3-data
sudo mkdir -p /data/energi3-data
sudo chmod a+w /data/energi3-data
```
Create your config file, refer to the example [energi3.conf]!(https://github.com/some_url/energi3.conf). Note rpcuser and rpcpassword to required for later ``energi3-cli`` usage for docker, so it is better to set those two options. Then please create the file ``${PWD}/energi3.conf`` with content:
```
rpcuser=energi3
rpcpassword=energi3
```
<h3>Launch energi3d</h3>
To launch energi3 node:
```
## to launch energi3d
$ docker run -d --rm --name energi3_node \
             -v ${PWD}/energi3.conf:/root/.energicore3/energi3.conf \
             -v /data/energi3-data/:/root/.energicore3/ \
             energi3/energi3 energi3

## check docker processed
$ docker ps

## to stop energi3d
$ docker run -i --network container:energi3_node \
             -v ${PWD}/energi3.conf:/root/.energicore3/energi3.conf \
             -v /data/energi3-data/:/root/.energicore3/ \
             energi3/energi3 energi3-cli stop
```
${PWD}/energi3.conf will be used, and blockchain data saved under /data/energi3-data/

<h3>Interact with energi3d using energi3-cli</h3>
Use following docker command to interact with your energi3 node with ``energi3-cli``:
```
$ docker run -i --network container:energi3_node \
             -v ${PWD}/energi3.conf:/root/.energicore3/energi3.conf \
             -v /data/energi3-data/:/root/.energicore3/ \
             energi3/energi3 energi3-cli getinfo
```
For more ``energi3-cli`` commands, use:
```
$ docker run -i --network container:energi3_node \
             -v ${PWD}/energi3.conf:/root/.energicore3/energi3.conf \
             -v /data/energi3-data/:/root/.energicore3/ \
             energi3/energi3 energi3-cli help
```
