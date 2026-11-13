FROM debian@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132

ARG TEA_VERSION=0.15.0
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server openssh-client ca-certificates \
      python3 python-is-python3 python3-venv \
      git build-essential nodejs npm \
      ripgrep jq curl wget less \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd \
 && rm -f /etc/ssh/ssh_host_*


COPY --from=ghcr.io/astral-sh/uv:0.11.32 /uv /uvx /usr/local/bin/

RUN curl -fsSL -o /usr/local/bin/tea \
      "https://dl.gitea.com/tea/${TEA_VERSION}/tea-${TEA_VERSION}-linux-${TARGETARCH}" \
 && chmod 755 /usr/local/bin/tea

RUN groupadd -g 10000 hermes-agent \
 && useradd -u 10000 -g 10000 --create-home --shell /bin/bash hermes-agent \
 && mkdir -p /home/hermes-agent/.ssh \
 && chown hermes-agent:hermes-agent /home/hermes-agent/.ssh \
 && chmod 700 /home/hermes-agent/.ssh

COPY --chown=hermes-agent:hermes-agent authorized_keys ssh_config /home/hermes-agent/.ssh/
RUN mv /home/hermes-agent/.ssh/ssh_config /home/hermes-agent/.ssh/config \
 && chmod 600 /home/hermes-agent/.ssh/authorized_keys /home/hermes-agent/.ssh/config

USER hermes-agent
RUN git config --global user.name "Hermes" \
 && git config --global user.email "hermes@lair.local" \
 && git config --global init.defaultBranch main
USER root

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh
CMD ["/usr/local/bin/entrypoint.sh"]
