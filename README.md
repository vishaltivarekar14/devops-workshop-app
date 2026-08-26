# DevOps Workshop App

A minimal Spring Boot application used to demonstrate a complete DevOps pipeline:
**GitHub → Build → Docker → Kubernetes → Running Service**

## What it does

Exposes two endpoints:
- `GET /api/hello` — returns `Hello from DevOps Workshop!`
- `GET /actuator/health` — Spring Boot health check (used by Kubernetes probes)

---

## Prerequisites

- Java 21
- Maven 3.9+
- Docker (via Colima)
- kubectl + k3s (via Colima)

---

## 1. Run with Maven (local, no Docker)

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
mvn spring-boot:run
curl http://localhost:8080/api/hello
curl http://localhost:8080/actuator/health
```

---

## 2. Build the JAR

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
mvn clean package -DskipTests
```

The JAR is created at `target/devops-1.0.0.jar`.

---

## 3. Run unit tests

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
mvn test
```

---

## 4. Build the Docker image

> Make sure Docker (Colima) is running: `colima status`

```bash
docker build -t devops-workshop-app:1.0.0 .
docker images | grep devops-workshop-app
```

---

## 5. Run the Docker container locally

```bash
docker run -d -p 8080:8080 --name devops-workshop devops-workshop-app:1.0.0
curl http://localhost:8080/api/hello
curl http://localhost:8080/actuator/health
docker stop devops-workshop && docker rm devops-workshop
```

---

## 6. Load the image into k3s (Colima)

k3s does not share Docker's image cache. Load the image into the cluster:

```bash
docker save devops-workshop-app:1.0.0 | colima ssh -- sudo k3s ctr images import -
```

Verify:
```bash
colima ssh -- sudo k3s ctr images ls | grep devops-workshop-app
```

---

## 7. Deploy to Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

---

## 8. Check Pods

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

Wait until STATUS is `Running` and READY is `1/1`.

---

## 9. Check the Service

```bash
kubectl get service devops-workshop-app
```

---

## 10. Access the application

Use `kubectl port-forward` to reach the ClusterIP service from your Mac:

```bash
kubectl port-forward service/devops-workshop-app 8080:80
```

Then in another terminal:
```bash
curl http://localhost:8080/api/hello
curl http://localhost:8080/actuator/health
```

---

## 11. Demonstrate Kubernetes self-healing

Open two terminals.

**Terminal 1** — watch pods:
```bash
kubectl get pods -w
```

**Terminal 2** — delete the pod:
```bash
kubectl delete pod <pod-name>
```

You will see Kubernetes immediately create a replacement pod. This is the **self-healing** feature of a Deployment.

---

## 12. Connect to personal GitHub (when ready)

```bash
git remote add origin git@github.com:<your-github-username>/devops-workshop-app.git
git remote -v   # verify it points to YOUR personal GitHub, not Bitbucket
git push -u origin main
```

---

## Project structure

```
app/
├── Dockerfile
├── README.md
├── pom.xml
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
└── src/
    ├── main/java/com/workshop/devops/
    │   ├── DevopsApplication.java
    │   └── HelloController.java
    └── test/java/com/workshop/devops/
        └── HelloControllerTest.java
```
