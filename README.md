# dk8s

The goal of this project is to deploy quickly a local k8s cluster in order to be able to experiment k8s deployment with all tools (grafana/prometheus/loki...).


In order to use the script 'local-cluster.sh', you need :

- helm
- helm-diff  (plugin)
- helmfile
- docker
- kind
- mkcert

To install requirements use `scripts/install-prereq.sh`

## How to

Deploy kind cluster:

### First deployment

```
./local-cluster.sh
```

Everything is deployed in default namespace for simplicity. After the deployment you can access to :

https://grafana.127.0.0.1.nip.io

```
admin / prom-operator
```

and :

https://argocd.127.0.0.1.nip.io

```
admin / admin
```

### Use local docker image

The ./local-cluster.sh create a local registry. In order to use it, you just need to tag docker image as follow:

```
docker tag alpine:latest localhost:5001/alpine:latest
docker push localhost:5001/alpine:latest
```

Then change value for the  docker image in the values.grist.yaml  as follow :

```
 image:
   repository: localhost:5001/alpine
   pullPolicy: Always
   tag: latest
```
