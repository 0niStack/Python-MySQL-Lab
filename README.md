# Python + MySQL (Docker + Kubernetes)

FastAPI + SQLAlchemy app backed by MySQL 8.4. MySQL accepts traffic **only from the app**.

## Layout
```
.github/workflows/docker.yml   CI: test -> build -> push image to GHCR
app/                FastAPI code (config, database, models, schemas, routers)
tests/              pytest (SQLite, no MySQL needed)
Dockerfile          multi-stage, non-root image
docker-compose.yml  app + db; db on an internal network, no published port
k8s/                namespaces, quotas, mysql, app, network policies
scripts/            create-secrets.sh, verify-network-policy.sh
```

## 1) Run locally with Docker Compose
```bash
cp .env.example .env        # edit passwords
docker compose up --build -d
curl localhost:8000/health/ready
docker compose down
```

## 2) Build the image with GitHub Actions
1. Push this repo to GitHub (branch `main`).
2. The workflow runs tests, builds the image and pushes it to
   `ghcr.io/<your-user>/<your-repo>` with tags `latest`, `sha-xxxx`, and `x.y.z` for tags like `v1.0.0`.
   Pull requests only build, they never push.
3. Repo -> Settings -> Actions -> General -> Workflow permissions must allow **Read and write**.
4. If the package is private, create a pull secret in the cluster and reference it in the deployment:
```bash
kubectl -n myapp create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<user> --docker-password=<PAT with read:packages>
# then add under spec.template.spec in k8s/app/deployment.yaml:
#   imagePullSecrets: [{name: ghcr-pull}]
```
   (Or set the package to Public in GitHub and skip this.)

## 3) Deploy to Kubernetes (any cluster)
Requirements: `kubectl` pointing at your cluster, and a CNI that enforces NetworkPolicy
(Calico, Cilium, etc. - most managed clusters like EKS/GKE/AKS can enable it).
```bash
make k8s-up IMAGE=ghcr.io/<your-user>/<your-repo>:latest
make k8s-status
kubectl -n myapp port-forward svc/web 8000:80
curl localhost:8000/items
make verify          # outside pod blocked, app pod can connect
make k8s-down        # delete everything
```

Without `make`:
```bash
kubectl apply -f k8s/00-namespaces.yaml
kubectl apply -f k8s/01-quotas.yaml
./scripts/create-secrets.sh
kubectl apply -f k8s/mysql/
kubectl apply -f k8s/app/
kubectl -n myapp set image deployment/web web=ghcr.io/<user>/<repo>:latest
kubectl apply -f k8s/network-policies.yaml
```

## What is restricted
| Control | Where |
|---|---|
| Separate namespaces `myapp` / `mydb` | k8s/00-namespaces.yaml |
| Pod Security `restricted` (non-root, no priv. escalation, drop ALL caps, seccomp) | namespace labels + pod specs |
| ResourceQuota + LimitRange | k8s/01-quotas.yaml |
| Default-deny; MySQL reachable only from `app=web` in `myapp` on 3306 | k8s/network-policies.yaml |
| App egress limited to DNS + MySQL | k8s/network-policies.yaml |
| No service-account tokens mounted | serviceaccount.yaml files |
| Random secrets generated in-cluster, not in git | scripts/create-secrets.sh |
| MySQL is ClusterIP only | k8s/mysql/service.yaml |

For external access install an ingress controller in namespace `ingress-nginx`
(policy allows only that namespace to reach the web pods).
If the MySQL pod is rejected by `restricted`, set the `mydb` namespace labels to `baseline`.
