# jdp-helm

Helm charts for my home lab

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
