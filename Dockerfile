FROM jenkins/jenkins:lts

USER root

# Install necessary packages
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    wget \
    git

# Install Java (Amazon Corretto)
RUN apt-get update && apt-get install -y software-properties-common \
    && wget -O - https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | tee /etc/apt/sources.list.d/corretto.list \
    && apt-get update \
    && apt-get install -y java-common java-21-amazon-corretto-jdk

# Install Maven
RUN apt-get install -y maven

# Install Python and pip
RUN apt-get install -y python3 python3-pip python3-venv \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Install Go
RUN wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz \
    && rm go1.21.0.linux-amd64.tar.gz

# Install Docker CLI for Docker-in-Docker support
RUN curl -fsSL https://get.docker.com | sh

# Set environment variables
ENV PATH=$PATH:/usr/local/go/bin
ENV JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto

# Create workspace directory
RUN mkdir -p /var/jenkins_home/workspace
RUN chown -R jenkins:jenkins /var/jenkins_home/workspace

# Switch back to jenkins user
USER jenkins

# Jenkins runs on port 8080 by default, and we'll expose the agent port as well
EXPOSE 8080 50000

# Copy custom configurations if needed
# COPY jenkins-config/ /var/jenkins_home/

# Skip the initial setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Initialize plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

