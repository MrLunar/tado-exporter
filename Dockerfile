ARG BUILD_IMAGE=openjdk:8
ARG TEST_IMAGE=adoptopenjdk/openjdk14:alpine
ARG RUNTIME_IMAGE=adoptopenjdk/openjdk14:alpine-jre

FROM $BUILD_IMAGE as builder

WORKDIR /build

COPY .mvn /build/.mvn/
COPY mvnw pom.xml /build/
COPY tado-api/pom.xml /build/tado-api/pom.xml
COPY tado-util/pom.xml /build/tado-util/pom.xml
COPY tado-exporter/pom.xml /build/tado-exporter/pom.xml

RUN ./mvnw -B de.qaware.maven:go-offline-maven-plugin:resolve-dependencies

COPY tado-api/src /build/tado-api/src
RUN ./mvnw -B -pl tado-api -am install

COPY tado-util/src /build/tado-util/src
RUN ./mvnw -B -pl tado-util -am install

COPY tado-exporter/src /build/tado-exporter/src
RUN ./mvnw -B package

# Integration tests
FROM $TEST_IMAGE as test

WORKDIR /build

COPY --from=builder /root/.m2/repository /root/.m2/repository
COPY --from=builder /build /build

RUN ./mvnw -B surefire:test failsafe:integration-test failsafe:verify

# Build runtime image
FROM $RUNTIME_IMAGE

COPY --from=builder /build/tado-exporter/target/tado-exporter-*.jar tado-exporter.jar
ENV JAVA_OPTS -Xmx64m -Xms64m
EXPOSE 8080
USER 65535:65535
CMD java ${JAVA_OPTS} -jar tado-exporter.jar
