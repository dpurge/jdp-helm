# jdp-helm

Helm charts for my home lab.

## Developing

```sh
sudo dnf install kubernetes1.32-client
sudo dnf install helm
```

```sh
helm create example
helm dependency update
helm package example
mv example-0.1.0.tgz docs
helm repo index docs --url https://dpurge.github.io/jdp-helm
```

## Installation

From local filesystem:

```sh
kubectl create namespace backend
helm install jdp-backend jdp-backend/ --values jdp-backend/values.yaml --namespace backend
helm upgrade jdp-backend jdp-backend/ --values jdp-backend/values.yaml --namespace backend

kubectl create namespace monitoring
helm install jdp-monitoring jdp-monitoring/ --values jdp-monitoring/values.yaml --namespace monitoring
helm upgrade jdp-monitoring jdp-monitoring/ --values jdp-monitoring/values.yaml --namespace monitoring
helm uninstall jdp-monitoring --namespace monitoring --dry-run

kubectl create namespace data
helm install jdp-data jdp-data/ --values jdp-data/values.yaml --namespace data
helm upgrade jdp-data jdp-data/ --values jdp-data/values.yaml --namespace data

kubectl create namespace workflow
helm install jdp-workflow jdp-workflow/ --values jdp-workflow/values.yaml --namespace workflow
helm upgrade jdp-workflow jdp-workflow/ --values jdp-workflow/values.yaml --namespace workflow
```

From repository:

```sh
helm repo add jdp-helm https://dpurge.github.io/jdp-helm
helm repo update

kubectl create namespace monitoring
helm install --name jdp-monitoring jdp-helm/jdp-monitoring -f custom-values.yaml --namespace monitoring
helm upgrade jdp-monitoring jdp-helm/jdp-monitoring --namespace monitoring
```

Uninstall:

```sh
helm uninstall jdp-monitoring -n monitoring
```

## Managing resources

```sh
helm install jdp-backend jdp-backend\
kubectl port-forward service/jdp-backend-argo-workflows-server 2746:2746
helm uninstall jdp-backend
```

## Sealing secrets

```sh
cat secret.yaml | kubeseal --controller-namespace jdp-backend --controller-name jdp-backend-sealed-secrets --format yaml > sealed-secret.yaml
```
