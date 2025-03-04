# ---- Base Stage ----
FROM ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:libreoffice/ppa
RUN apt-get update
RUN apt-get install -y libreoffice
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*


# ---- Java Stage ----
FROM base AS base_java
ARG TARGETPLATFORM
RUN apt-get update && apt-get install -y wget
ARG JAVA_FILE_NAME=java17.tar.gz

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        JAVA_SOURCE="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8.1%2B1/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.8.1_1.tar.gz"; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        JAVA_SOURCE="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8.1%2B1/OpenJDK17U-jdk_x64_linux_hotspot_17.0.8.1_1.tar.gz"; \
    else \
        echo "Unsupported platform: $TARGETPLATFORM"; \
        exit 1; \
    fi && \
    wget -O $JAVA_FILE_NAME $JAVA_SOURCE && \
    tar -xzvf $JAVA_FILE_NAME -C /usr/local && \
    rm $JAVA_FILE_NAME

ENV JAVA_HOME=/usr/local/jdk-17.0.8.1+1
ENV PATH=$JAVA_HOME/bin:$PATH

# ---- Maven Stage ----
FROM base_java AS base_java_maven
ARG MAVEN_SOURCE="https://dlcdn.apache.org/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz"
ARG MAVEN_FILE_NAME=maven.tar.gz
RUN wget -O $MAVEN_FILE_NAME $MAVEN_SOURCE
RUN tar -xzvf $MAVEN_FILE_NAME -C /usr/local
RUN rm $MAVEN_FILE_NAME
ENV MAVEN_HOME=/usr/local/apache-maven-3.9.5
ENV PATH=$MAVEN_HOME/bin:$PATH

# ----app stage----
FROM base_java_maven

WORKDIR /project
COPY ./pom.xml .
RUN mvn verify clean -Dmaven.artifact.threads=8 --fail-never

COPY ./src ./src
RUN mvn package

RUN cp ./target/*.jar ./app.jar
COPY ./fonts/ /usr/share/fonts/custom
RUN rm -rf ./src ./pom.xml
EXPOSE 8080

CMD ["java", "-jar", "./app.jar"]
