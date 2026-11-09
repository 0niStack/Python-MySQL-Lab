.RECIPEPREFIX := >
# Your image pushed by GitHub Actions, e.g. ghcr.io/youruser/python-mysql-k8s:latest
IMAGE ?= ghcr.io/YOUR_GITHUB_USER/YOUR_REPO:latest

.PHONY: test build up down k8s-up k8s-status k8s-down verify

test:
> pip install -q -r requirements.txt && pytest -q

build:
> docker build -t $(IMAGE) .

up:
> docker compose up --build -d

down:
> docker compose down

k8s-up:
> kubectl apply -f k8s/00-namespaces.yaml
> kubectl apply -f k8s/01-quotas.yaml
> ./scripts/create-secrets.sh
> kubectl apply -f k8s/mysql/
> kubectl -n mydb rollout status statefulset/mysql --timeout=180s
> kubectl apply -f k8s/app/
> kubectl -n myapp set image deployment/web web=$(IMAGE)
> kubectl apply -f k8s/network-policies.yaml
> kubectl -n myapp rollout status deployment/web --timeout=180s

k8s-status:
> kubectl get pods,svc,networkpolicy -n myapp
> kubectl get pods,svc,pvc,networkpolicy -n mydb

k8s-down:
> kubectl delete ns myapp mydb

verify:
> ./scripts/verify-network-policy.sh
