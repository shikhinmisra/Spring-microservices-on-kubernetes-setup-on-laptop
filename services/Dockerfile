# Shared image build for all Spring Boot services (builds for the host CPU, e.g. amd64 on Windows/Intel).
# Build context must be the repository root (the parent pom lives there):
#   docker build -f services/Dockerfile --build-arg SERVICE=product-service -t <registry>/microservices/product-service:<tag> .
FROM maven:3.9-eclipse-temurin-21 AS build
ARG SERVICE
WORKDIR /src
COPY pom.xml .
COPY services ./services
RUN --mount=type=cache,target=/root/.m2 \
    mvn -q -B -pl services/${SERVICE} -am package -Dmaven.test.skip=true && \
    cp services/${SERVICE}/target/${SERVICE}-*.jar /app.jar

FROM eclipse-temurin:21-jre
COPY --from=build /app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
