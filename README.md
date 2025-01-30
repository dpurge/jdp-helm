# jdp-helm

Helm charts for my home lab.

## Developing

```sh
sudo dnf install kubernetes1.32-client
sudo dnf install helm
```

```sh
helm create example
helm package example
mv example-0.1.0.tgz docs
helm repo index docs --url https://dpurge.github.com/jdp-helm
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
