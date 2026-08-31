/*
 * ══════════════════════════════════════════════════════════════════
 *  DEVOPS WORKSHOP — CI/CD PIPELINE
 * ══════════════════════════════════════════════════════════════════
 *
 *  WHAT IS A JENKINSFILE?
 *  A Jenkinsfile defines your pipeline as code — it lives in your
 *  repository alongside your source code. Every change to the
 *  pipeline is tracked in Git history, reviewed in PRs, and
 *  version-controlled just like your application code.
 *  This is called "Pipeline as Code."
 *
 *  PIPELINE STAGES (in order):
 *  1. Checkout          — Pull source code from Git
 *  2. Compile           — Compile Java source files
 *  3. Checkstyle        — Enforce coding style rules (DevSecOps gate)
 *  4. Unit Test         — Run JUnit tests and publish results
 *  5. Package           — Build the runnable JAR artifact
 *  6. Docker Build      — Package JAR into a Docker image
 *  7. SonarQube         — Static analysis: bugs, smells, coverage
 *  8. Trivy Scan        — Scan Docker image for CVEs (DevSecOps gate)
 *  9. Deploy to K8s     — Roll out the image to Kubernetes
 * ══════════════════════════════════════════════════════════════════
 */

pipeline {
    agent any

    tools {
        maven 'Maven-3.9.16'
    }

    environment {
        APP_NAME     = 'devops-workshop-app'
        IMAGE_TAG    = "1.0.${BUILD_NUMBER}"
        IMAGE_FULL   = "${APP_NAME}:1.0.${BUILD_NUMBER}"
        IMAGE_LATEST = "${APP_NAME}:latest"
        K8S_MANIFEST = 'k8s/deployment.yaml'
    }

    stages {

        // ─────────────────────────────────────────────────────────
        // STAGE 1 — CHECKOUT
        // Pull the latest source code from the Git repository.
        // "scm" means "Source Control Management" — Jenkins reads
        // the repo URL from the job configuration automatically.
        // ─────────────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                echo "Checked out: ${GIT_BRANCH} @ ${GIT_COMMIT?.take(7)}"
            }
        }

        // ─────────────────────────────────────────────────────────
        // STAGE 2 — COMPILE
        // Compiles Java source files using Maven. Fails fast if
        // there are any syntax or compilation errors — no point
        // running tests on broken code.
        // ─────────────────────────────────────────────────────────
        stage('Compile') {
            steps {
                sh 'mvn compile -q'
                echo 'Compilation successful'
            }
        }

        // ─────────────────────────────────────────────────────────
        // STAGE 3 — CHECKSTYLE  (Code Quality Gate)
        // Runs Checkstyle against all Java source files using the
        // rules defined in checkstyle.xml. This is a DevSecOps
        // "shift-left" practice — catching style and quality issues
        // early, before they reach code review or production.
        // Pipeline FAILS if any rule is violated.
        // ─────────────────────────────────────────────────────────
        stage('Checkstyle') {
            steps {
                sh 'mvn checkstyle:check'
                echo 'Code style check passed'
            }
        }

        // ─────────────────────────────────────────────────────────
        // STAGE 4 — UNIT TEST
        // Runs all JUnit tests via Maven Surefire plugin. Jenkins
        // archives the XML results so the test report tab shows
        // pass/fail history across builds. Build is marked UNSTABLE
        // if tests fail (visible as yellow in the Jenkins UI).
        // ─────────────────────────────────────────────────────────
        stage('Unit Test') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        // ─────────────────────────────────────────────────────────
        // STAGE 5 — PACKAGE
        // Creates the final runnable JAR (Spring Boot "fat JAR")
        // that bundles the app + all dependencies into one file.
        // -DskipTests avoids running tests twice.
        // The JAR is archived so it can be downloaded from Jenkins.
        // ─────────────────────────────────────────────────────────
        stage('Package') {
            steps {
                sh 'mvn package -DskipTests -q'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                echo 'Artifact archived: target/devops-1.0.0.jar'
            }
        }

        // ─────────────────────────────────────────────────────────
        // STAGE 6 — DOCKER BUILD
        // Packages the JAR into a Docker image using the Dockerfile
        // at the repo root. This image is what Kubernetes will run.
        //
        // PREREQUISITE: Jenkins must be started with Docker socket
        // mounted. See README.md section "Jenkins + Docker Setup".
        // One-time command:
        //   docker run -d -p 8080:8080 -p 50000:50000 \
        //     -v jenkins_home:/var/jenkins_home \
        //     -v /var/run/docker.sock:/var/run/docker.sock \
        //     --group-add $(stat -f%g /var/run/docker.sock) \
        //     jenkins/jenkins:lts
        // ─────────────────────────────────────────────────────────
        stage('Docker Build') {
            steps {
                sh """
                    docker build \\
                        --tag ${APP_NAME}:1.0.${BUILD_NUMBER} \\
                        --tag ${APP_NAME}:latest \\
                        --label build=${BUILD_NUMBER} \\
                        .
                """
                echo "Docker image built: ${APP_NAME}:1.0.${BUILD_NUMBER}"
            }
        }

        // ─────────────────────────────────────────────────────────
        // STAGE 7 — SONARQUBE ANALYSIS  (Code Quality Gate)
        // SonarQube performs static code analysis — it reads your
        // source code without running it and detects:
        //   • Bugs        — code that will likely fail at runtime
        //   • Code Smells — maintainability issues (too complex,
        //                   duplicated code, poor naming, etc.)
        //   • Security Hotspots — places that need human review
        //   • Coverage    — which lines are covered by unit tests
        //
        // The result appears as a "Quality Gate" — PASSED or FAILED.
        // A failed Quality Gate can block deployment.
        //
        // PREREQUISITE:
        //   1. SonarQube running at http://sonarqube:9000
        //   2. Token added as Jenkins secret: ID = sonarqube-token
        //   3. SonarQube Scanner plugin installed in Jenkins
        // ─────────────────────────────────────────────────────────
        stage('SonarQube Analysis') {
            environment {
                SONAR_TOKEN = credentials('sonarqube-token')
            }
            steps {
                sh """
                    mvn sonar:sonar \
                        -Dsonar.projectKey=devops-workshop-app \
                        -Dsonar.projectName='DevOps Workshop App' \
                        -Dsonar.host.url=http://sonarqube:9000 \
                        -Dsonar.token=\$SONAR_TOKEN
                """
                echo 'SonarQube analysis complete — check http://localhost:9000'
            }
        }

        // ─────────────────────────────────────────────────────────
        // STAGE 8 — TRIVY SECURITY SCAN  (DevSecOps Gate)
        // Trivy (by Aqua Security) scans the Docker image for CVEs
        // (Common Vulnerabilities and Exposures). It checks every
        // OS package and library layer against multiple vulnerability
        // databases: NVD, GitHub Advisory, Alpine SecDB, etc.
        //
        // --exit-code 1       → fail the pipeline if issues found
        // --severity HIGH,CRITICAL → only block on serious CVEs;
        //                       LOW/MEDIUM appear in the report
        //                       but don't stop the build
        // --format table      → human-readable output in logs
        // --output            → also saves a JSON report as artifact
        //
        // No account or token needed — Trivy is fully open source.
        // ─────────────────────────────────────────────────────────
        stage('Trivy Security Scan') {
            steps {
                sh """
                    trivy image \
                        --exit-code 1 \
                        --severity HIGH,CRITICAL \
                        --ignorefile .trivyignore \
                        --format table \
                        ${APP_NAME}:1.0.${BUILD_NUMBER}

                    trivy image \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --ignorefile .trivyignore \
                        --format json \
                        --output trivy-report.json \
                        ${APP_NAME}:1.0.${BUILD_NUMBER}
                """
                echo 'Trivy scan complete — check trivy-report.json for full findings'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                }
            }
        }

        // ─────────────────────────────────────────────────────────
        // STAGE 8 — DEPLOY TO KUBERNETES
        // Patches the image tag in deployment.yaml, then applies
        // both manifests to the local k3s cluster via kubectl.
        // Kubernetes performs a rolling update — gradually replacing
        // old Pods with new ones for zero-downtime deployment.
        // kubectl rollout status waits until all Pods are healthy.
        // ─────────────────────────────────────────────────────────
        stage('Deploy to Kubernetes') {
            environment {
                KUBECONFIG = '/var/jenkins_home/.kube/config'
            }
            steps {
                sh """
                    sed 's|image: ${APP_NAME}:.*|image: ${APP_NAME}:1.0.${BUILD_NUMBER}|g' \\
                        ${K8S_MANIFEST} | kubectl apply -f -

                    kubectl apply -f k8s/service.yaml

                    kubectl rollout status deployment/${APP_NAME} --timeout=120s
                """
                echo "Deployed ${APP_NAME}:1.0.${BUILD_NUMBER} to Kubernetes"
            }
            post {
                success {
                    sh "KUBECONFIG=/var/jenkins_home/.kube/config kubectl get pods -l app=${APP_NAME} -o wide"
                }
            }
        }
    }

    post {
        success {
            echo "BUILD ${BUILD_NUMBER} — ALL STAGES PASSED"
        }
        failure {
            echo "BUILD ${BUILD_NUMBER} — PIPELINE FAILED — check stage logs above"
        }
        always {
            cleanWs()
        }
    }
}
