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
