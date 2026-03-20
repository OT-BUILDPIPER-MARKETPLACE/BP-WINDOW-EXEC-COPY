FROM ubuntu:22.04

RUN apt update && apt install -y \
  sshpass \
  bash \
  jq \
  file \
  dos2unix \
  git \
  nano \
  vim \
  curl \
  gettext \
  python3 \
  python3-pip \
  python3-venv \
  && apt clean

RUN groupadd -g 65522 buildpiper && \
    useradd -u 65522 -g buildpiper -d /home/buildpiper -m -s /bin/bash buildpiper && \
    mkdir -p /bp /bp/workspace /bp/data /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /bp /home/buildpiper

COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/ /opt/buildpiper/shell-functions/

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install \
        tabulate \
        cryptography

ENV PATH="/opt/venv/bin:$PATH"

ENV SLEEP_DURATION=5s
ENV ACTIVITY_SUB_TASK_CODE=CF_STEP

USER buildpiper
WORKDIR /home/buildpiper

ENTRYPOINT ["./build.sh"]
