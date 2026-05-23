# ---- Builder: Java + Maven on Ubuntu ----
FROM ubuntu:24.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETPLATFORM
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# Install Temurin JDK 17 (build only)
ARG JAVA_FILE_NAME=java17.tar.gz
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        JAVA_SOURCE="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8.1%2B1/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.8.1_1.tar.gz"; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        JAVA_SOURCE="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8.1%2B1/OpenJDK17U-jdk_x64_linux_hotspot_17.0.8.1_1.tar.gz"; \
    else \
        echo "Unsupported platform: $TARGETPLATFORM"; exit 1; \
    fi && \
    wget -O $JAVA_FILE_NAME $JAVA_SOURCE && \
    tar -xzvf $JAVA_FILE_NAME -C /usr/local && \
    rm $JAVA_FILE_NAME

ENV JAVA_HOME=/usr/local/jdk-17.0.8.1+1
ENV PATH=$JAVA_HOME/bin:$PATH

# Install Maven 3.9.5 (pinned, build only)
ARG MAVEN_SOURCE="https://archive.apache.org/dist/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz"
ARG MAVEN_FILE_NAME=maven.tar.gz
RUN wget -O $MAVEN_FILE_NAME $MAVEN_SOURCE && \
    tar -xzvf $MAVEN_FILE_NAME -C /usr/local && \
    rm $MAVEN_FILE_NAME
ENV MAVEN_HOME=/usr/local/apache-maven-3.9.5
ENV PATH=$MAVEN_HOME/bin:$PATH

# Pre-fetch dependencies (layer cached until pom.xml changes)
WORKDIR /project
COPY ./pom.xml .
RUN mvn verify clean -Dmaven.artifact.threads=8 --fail-never

# Build the application jar
COPY ./src ./src
RUN mvn package -DskipTests


# ---- Runtime: lean Ubuntu + LibreOffice + JRE only ----
FROM ubuntu:24.04 AS runtime
ENV DEBIAN_FRONTEND=noninteractive

# Install LibreOffice and Temurin JRE 17
ARG TARGETPLATFORM
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y software-properties-common wget && \
    add-apt-repository ppa:libreoffice/ppa && \
    apt-get update && \
    apt-get install -y libreoffice && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Temurin JRE 17 (runtime only — smaller than the full JDK)
ARG JAVA_FILE_NAME=java17-jre.tar.gz
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        JAVA_SOURCE="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8.1%2B1/OpenJDK17U-jre_aarch64_linux_hotspot_17.0.8.1_1.tar.gz"; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        JAVA_SOURCE="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8.1%2B1/OpenJDK17U-jre_x64_linux_hotspot_17.0.8.1_1.tar.gz"; \
    else \
        echo "Unsupported platform: $TARGETPLATFORM"; exit 1; \
    fi && \
    wget -O $JAVA_FILE_NAME $JAVA_SOURCE && \
    tar -xzvf $JAVA_FILE_NAME -C /usr/local && \
    rm $JAVA_FILE_NAME && \
    # Symlink the extracted JRE directory (name varies by Temurin release) to a stable path
    ln -s "$(ls -d /usr/local/jdk-17*)" /usr/local/java17 && \
    apt-get purge -y wget && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/local/java17
ENV PATH=$JAVA_HOME/bin:$PATH

# Copy only the built artifact and custom fonts — no Maven, no .m2, no build tools
WORKDIR /app
COPY --from=builder /project/target/*.jar ./app.jar
COPY ./fonts/ /usr/share/fonts/custom

RUN chown -R ubuntu:ubuntu /app
USER ubuntu
EXPOSE 8080

CMD ["java", "-jar", "./app.jar"]
