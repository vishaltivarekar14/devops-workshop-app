# DevOps Workshop — End-to-End Pipeline Demo

A Spring Boot application demonstrating a complete, industry-style DevOps pipeline:

```
GitHub → Jenkins CI → Docker → Snyk Security Scan → Kubernetes
```

---

## Table of Contents

1. [Concepts at a Glance](#1-concepts-at-a-glance)
2. [Pipeline Overview](#2-pipeline-overview)
3. [Jenkins + Docker Setup (One-Time Fix)](#3-jenkins--docker-setup-one-time-fix)
4. [Jenkins + Snyk Setup](#4-jenkins--snyk-setup)
5. [Run Locally (no Docker)](#5-run-locally-no-docker)
6. [Run Tests + Checkstyle](#6-run-tests--checkstyle)
7. [Build Docker Image](#7-build-docker-image)
8. [Deploy to Kubernetes](#8-deploy-to-kubernetes)
9. [Demo Scripts for Workshop](#9-demo-scripts-for-workshop)
10. [Project Structure](#10-project-structure)

---

## 1. Concepts at a Glance

### What is a Container?
A container packages an application with everything it needs to run — the code, runtime (JRE), libraries, and configuration — into a single portable unit. It runs in isolation from other processes on the same machine. Think of it like a lightweight virtual machine, but sharing the host OS kernel (so it starts in milliseconds, not minutes).

### What is Docker?
Docker is the most popular tool for building and running containers. Key terms:

| Term | Meaning |
|---|---|
| **Image** | A read-only template. Like a class in Java — it is a blueprint. |
| **Container** | A running instance of an image. Like an object in Java — it is a live thing. |
| **Dockerfile** | A script of instructions that builds an image, layer by layer. |
| **Docker Hub** | A public registry where images are stored and shared. |

### What is Kubernetes (K8s)?
Kubernetes is a container orchestration platform — it manages running containers across a cluster of machines. It provides:
- **Self-healing**: restarts crashed containers automatically
- **Scaling**: run 1 or 100 copies with one command
- **Rolling updates**: deploy new versions with zero downtime
- **Service discovery**: containers find each other by name, not IP

### What is a Pod?
A Pod is the smallest deployable unit in Kubernetes. It wraps one or more containers that share:
- Network (same IP address)
- Storage volumes

Most of the time, one Pod = one container. Pods are ephemeral — they can be killed and recreated at any time. You never manage Pods directly; you use a Deployment.

### What is a Deployment?
A Deployment declares the desired state: "I want 3 replicas of image X running at all times." Kubernetes continuously reconciles the actual state to match the desired state. If a Pod dies, the Deployment controller immediately starts a new one.

### What is a Service?
A Service gives your Pods a stable DNS name and IP address. Since Pods come and go, their IPs change — a Service is the stable front door that load-balances traffic to the currently healthy Pods.

### What is CI/CD?
| Term | Meaning |
|---|---|
| **CI** (Continuous Integration) | Every code push automatically triggers build + test. Catches bugs early. |
| **CD** (Continuous Delivery) | Every successful CI build is automatically deployed to an environment. |
| **Pipeline** | The sequence of automated steps from code commit to deployed app. |

### What is DevSecOps?
DevSecOps = Development + Security + Operations. It means shifting security checks left — running them automatically in the pipeline (on every commit) rather than as a manual audit at the end. In our pipeline: Checkstyle and Snyk are the DevSecOps gates.

---

## 2. Pipeline Overview

```
┌─────────────┐    push     ┌──────────────────────────────────────────────────────────────┐
│   Developer │ ──────────► │                    JENKINS PIPELINE                          │
│   Git Push  │             │                                                              │
└─────────────┘             │  ┌──────────┐  ┌──────────┐  ┌────────────┐  ┌──────────┐  │
                            │  │ Checkout │→ │ Compile  │→ │ Checkstyle │→ │Unit Test │  │
                            │  └──────────┘  └──────────┘  └────────────┘  └──────────┘  │
                            │                                    ↓ FAIL = pipeline stops   │
                            │  ┌──────────┐  ┌─────────────┐  ┌──────────┐               │
                            │  │  Deploy  │← │  Snyk Scan  │← │  Package │               │
                            │  │  to K8s  │  │ (CVE check) │  │  + Docker│               │
                            │  └──────────┘  └─────────────┘  └──────────┘               │
                            └──────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                            ┌──────────────┐
                            │  Kubernetes  │  http://localhost:30080/api/hello
                            │   (k3s)      │  http://localhost:30080/actuator/health
                            └──────────────┘
```

---

## 3. Jenkins + Docker Setup (One-Time Fix)

Your current Jenkins container does **not** have Docker access. The Docker build stage will fail until you recreate Jenkins with the Docker socket mounted.

**Step 1 — Stop and remove the existing Jenkins container** (data is safe in the volume):
```bash
docker stop jenkins
docker rm jenkins
```

**Step 2 — Get the Docker socket group ID on your Mac (via Colima)**:
```bash
# The socket is at /var/run/docker.sock inside Colima's VM
DOCKER_GID=$(stat -f%g /var/run/docker.sock 2>/dev/null || echo 970)
echo "Docker GID: $DOCKER_GID"
```

**Step 3 — Restart Jenkins with the Docker socket mounted**:
```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(stat -f%g /var/run/docker.sock) \
  jenkins/jenkins:lts
```

**Step 4 — Install Docker CLI inside the Jenkins container**:
```bash
docker exec -u root jenkins bash -c "
  apt-get update -q &&
  apt-get install -y docker.io &&
  chmod 666 /var/run/docker.sock
"
```

**Step 5 — Verify**:
```bash
docker exec jenkins docker ps
# Should list running containers — if it does, Jenkins can now run Docker commands
```

---

## 4. Jenkins + Trivy Setup

Trivy requires **no account and no token** — just install the binary inside Jenkins once.

```bash
docker exec -u root jenkins bash -c "
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin &&
  trivy --version
"
```

That's it. The pipeline Trivy stage will work immediately after this.

---

## 5. Run Locally (no Docker)

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
mvn spring-boot:run
```

Test endpoints:
```bash
curl http://localhost:8080/api/hello
# → Hello from DevOps Workshop!

curl http://localhost:8080/actuator/health
# → {"status":"UP"}
```

---

## 6. Run Tests + Checkstyle

```bash
# Run unit tests
mvn test

# Run Checkstyle only
mvn checkstyle:check

# Full CI sequence (what Jenkins does):
mvn compile checkstyle:check test package -DskipTests
```

---

## 7. Build Docker Image

Make sure Colima (Docker) is running: `colima status`

```bash
# Build the image
docker build -t devops-workshop-app:1.0.0 .

# Verify it exists
docker images | grep devops-workshop-app

# Run it locally
docker run -d -p 8080:8080 --name demo devops-workshop-app:1.0.0
curl http://localhost:8080/api/hello

# Stop and remove
docker stop demo && docker rm demo
```

**Load image into k3s** (k3s does not share Docker's image cache):
```bash
docker save devops-workshop-app:1.0.0 | colima ssh -- sudo k3s ctr images import -

# Verify
colima ssh -- sudo k3s ctr images ls | grep devops-workshop-app
```

---

## 8. Deploy to Kubernetes

```bash
# Apply manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Watch pods come up
kubectl get pods -w

# Once Running/Ready, access the app (NodePort 30080)
curl http://localhost:30080/api/hello
curl http://localhost:30080/actuator/health
```

---

## 9. Demo Scripts for Workshop

### Demo A — Self-Healing
```bash
# Terminal 1: watch pods in real time
kubectl get pods -w

# Terminal 2: kill the pod
kubectl delete pod $(kubectl get pods -l app=devops-workshop-app -o name | head -1)

# Observe: Kubernetes immediately starts a replacement pod
```

### Demo B — Scale Up/Down
```bash
# Scale to 3 replicas
kubectl scale deployment devops-workshop-app --replicas=3
kubectl get pods

# Scale back to 1
kubectl scale deployment devops-workshop-app --replicas=1
```

### Demo C — Inspect a Pod
```bash
POD=$(kubectl get pods -l app=devops-workshop-app -o name | head -1)

# View logs
kubectl logs $POD

# Shell into the container
kubectl exec -it $POD -- sh

# Inside the container: prove isolation
cat /etc/os-release    # Alpine Linux — not your Mac
java -version          # JRE 21 — only what Dockerfile installed
ls /app                # only app.jar is here
exit
```

### Demo D — Describe a Pod (explain probes, events, resources)
```bash
kubectl describe pod $(kubectl get pods -l app=devops-workshop-app -o name | head -1)
```

---

## 10. Project Structure

```
devopslab/
├── Dockerfile                        # Builds the Docker image from the JAR
├── Jenkinsfile                       # Pipeline as Code — all 8 CI/CD stages
├── checkstyle.xml                    # Code style rules enforced in pipeline
├── pom.xml                           # Maven build config + plugin declarations
├── README.md                         # This file
├── k8s/
│   ├── deployment.yaml               # Kubernetes Deployment (manages Pods)
│   └── service.yaml                  # Kubernetes Service (NodePort → :30080)
└── src/
    ├── main/java/com/workshop/devops/
    │   ├── DevopsApplication.java    # Spring Boot entry point
    │   └── HelloController.java      # REST API: GET /api/hello
    └── test/java/com/workshop/devops/
        └── HelloControllerTest.java  # JUnit 5 test with MockMvc
```
