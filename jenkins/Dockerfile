FROM docker:28-cli AS docker-cli
FROM ghcr.io/astral-sh/uv:0.9.18 AS uv
FROM jenkins/jenkins:lts-jdk21

USER root
RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl python3 python3-venv \
    && rm -rf /var/lib/apt/lists/*
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose
COPY --from=uv /uv /usr/local/bin/uv
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
