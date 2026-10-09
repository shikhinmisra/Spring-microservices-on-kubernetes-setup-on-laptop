---
name: new-service
description: Scaffold a new Spring Boot microservice end to end - Maven module, code skeleton, integration test, Docker build, Kubernetes manifests and overlay image entry. Use when the user asks to create/add a new service or microservice.
argument-hint: "<service-name> [port] [mongodb|mysql|none] [kafka]"
---

# Create a new microservice: $ARGUMENTS

Name must be kebab-case ending in `-service` (e.g. `payment-service`). Package: `com.techie.microservices.<short>`
where `<short>` is the name without `-service` (e.g. `payment`). Pick the next free port (8080-8083 and 9000 are taken).
Use the closest existing service as the template: `inventory-service` (MySQL/Flyway), `product-service` (MongoDB),
`order-service` (MySQL + Kafka producer + REST client), `notification-service` (Kafka consumer).

## 1. Maven module
1. `services/<name>/pom.xml`: copy the template's pom. Parent = `spring-boot-3-microservices` with
   `<relativePath>../../pom.xml</relativePath>`. Keep only the dependencies this service needs; always keep
   actuator, springdoc, lombok, spring-boot-starter-test, spring-boot-testcontainers, junit-jupiter, rest-assured.
2. Add `<module>services/<name></module>` to the root `pom.xml`.

## 2. Code skeleton (`services/<name>/src/main/java/com/techie/microservices/<short>/`)
- `<Short>ServiceApplication.java`, `controller/`, `service/`, `repository/`, `model/`, `dto/` (records), `config/OpenAPIConfig.java`.
- `src/main/resources/application.properties`: `spring.application.name`, `server.port`, datasource defaults pointing at
  `localhost` (Kubernetes overrides them via env), springdoc paths `/swagger-ui.html` and `/api-docs`, actuator exposure.
- MySQL: Flyway migration `db/migration/V1__init.sql`, and add `CREATE DATABASE IF NOT EXISTS <short>_service;` to the
  `mysql-initdb-config` ConfigMap in `k8s/infrastructure/core/mysql.yml`.

## 3. Integration test (required)
`src/test/java/com/techie/microservices/<short>/<Short>ServiceApplicationTests.java` — `@SpringBootTest(webEnvironment = RANDOM_PORT)`,
Testcontainers with `@ServiceConnection` (`mysql:8.3.0` / `mongo:7.0.5` / `confluentinc/cp-kafka:7.5.0`), RestAssured calls
against the real endpoints. Follow `services/order-service/src/test/.../OrderServiceApplicationTests.java`.
Package must be `com.techie.microservices.<short>` (never `java.com...`). Run `mvn -pl services/<name> -am verify`.

## 4. Kubernetes
1. `k8s/apps/base/backend/<name>.yml` (or `edge/` if it is not core business logic): Deployment + Service + ConfigMap,
   copied from `inventory-service.yml`. Image must be the bare placeholder `image: <name>`. Add resource requests/limits
   (`requests: memory 256Mi, cpu 100m; limits: memory 512Mi`) — the laptop is memory-bound.
2. Add the file to that folder's `kustomization.yaml`.
3. Add an `images:` entry (`newName: localhost:30002/microservices/<name>`, `newTag: "1.0"`) to every overlay that
   includes that base (`overlays/local` for backend, `overlays/full` always).
4. Add the service URL to `k8s/apps/base/backend/common-config.yml` if other services call it.
5. Render to verify: `kubectl kustomize k8s/apps/overlays/local`.

## 5. Scripts and docs
- Add the name to `$Backend` (or `$Services`) in `scripts/windows/common.ps1`.
- Add a row to the Services table in `README.md`; note the port in `CLAUDE.md` Project facts.

## 6. Finish
Delegate a review to the `code-reviewer` and `k8s-manifest-reviewer` subagents. Then build/push with the
`release-version` skill (tag `1.0`) and deploy with `deploy-local` — only after checking memory.
