# Docker Consul Update

## To run

+ Build the Docker image
```
docker build --tag belly/docker_consul_update .
```

+ Run the Docker image with ENV variables
```
docker run -e CONSUL_IP='172.17.42.1' -e DOCKER_HOST='tcp://172.17.42.1:2376' belly/docker_consul_update
```
