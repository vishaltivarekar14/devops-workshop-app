FROM eclipse-temurin:21-jre-alpine

# Upgrade all Alpine packages to get the latest security patches.
# This is a DevSecOps best practice — even official base images can
# ship with packages that have known CVEs by the time you use them.
# apk upgrade pulls in the latest patched versions of OS libraries
# (OpenSSL, libcrypto, etc.) without changing the JRE itself.
RUN apk upgrade --no-cache

WORKDIR /app

COPY target/devops-*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
