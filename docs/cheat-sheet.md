# Cheat sheet

# kind cli
To Manage a cluster with your own config file
```
kind create cluster -n dev --config "clusters/dev.yaml"

kind get clusters
kind get nodes

kubectl get node -A
kubectl get pod -A

kind delete cluster -n dev
```
