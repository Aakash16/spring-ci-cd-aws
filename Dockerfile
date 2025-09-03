# Maven build container
FROM maven:3.8.5-openjdk-11 AS maven_build

COPY pom.xml /tmp/
COPY src /tmp/src/
WORKDIR /tmp/
RUN mvn clean package -DskipTests

# Runtime base image
FROM eclipse-temurin:11
WORKDIR /data
EXPOSE 8080

# Copy built jar
COPY --from=maven_build /tmp/target/spring-boot-cicd.jar /data/spring-boot-cicd.jar

# Use exec form for better container lifecycle handling
ENTRYPOINT ["java","-jar","/data/spring-boot-cicd.jar"]
