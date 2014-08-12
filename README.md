# Docker Consul Update

## To run

+ Build the Docker image
```
docker build .
```

+ Run the Docker image with ENV variables
```
docker run -e REMOTE_SCRIPT_URL='https://jockey.bellycard.com/container_update' -e CONSUL_URL='http://foo.io:8500' -e DOCKER_HOST='tcp://bar.io:2375' <image_id>
```
