---
name: add-feature
description: Add or change a feature (REST endpoint, business rule, Kafka event) in an existing service, test-first with @SpringBootTest + Testcontainers, then verify. Use for any change to Java code in services/.
argument-hint: "<service> <what to build>"
---

# Add a feature: $ARGUMENTS

1. **Locate**: read the service's controller, service, repository and existing tests. Keep the existing layering
   (controller -> service -> repository; DTOs as records; Lombok `@RequiredArgsConstructor`, `@Slf4j`).
2. **Test first**: add/extend an integration test in `services/<svc>/src/test/java/com/techie/microservices/<short>/`:
   - `@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)` + RestAssured.
   - Real dependencies via Testcontainers `@ServiceConnection`: `mysql:8.3.0`, `mongo:7.0.5`, `confluentinc/cp-kafka:7.5.0`
     (Schema Registry: `confluentinc/cp-schema-registry:7.5.0` as a GenericContainer). Never point tests at the cluster.
   - Calls to other services: WireMock stubs (`@AutoConfigureWireMock(port = 0)`), see order-service `stubs/`.
   - Cover the happy path and at least one failure (validation, not found, out of stock...).
3. **Implement** until the test passes. DB changes in MySQL services = a new Flyway file `V<n+1>__<desc>.sql`; never edit
   applied migrations. Avro schema changes must stay backward compatible (add fields with defaults).
4. **Verify**: `mvn -pl services/<svc> -am verify`. All tests must pass; report any failure verbatim, never `-DskipTests`.
   If Maven Central or Docker is unavailable, say so explicitly instead of claiming success.
5. **Review**: delegate to the `code-reviewer` subagent; fix what it flags as must-fix.
6. **Config**: new env-dependent settings go in `application.properties` (localhost default) AND the service's
   ConfigMap/env in `k8s/apps/base/...`.
7. Summarize what changed and suggest `release-version` if the user wants it running in the cluster.
