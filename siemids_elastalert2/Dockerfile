FROM python:3-slim-buster as builder

LABEL description="ElastAlert 2 Official Image"
LABEL maintainer="Jason Ertel"

COPY . /tmp/elastalert

RUN mkdir -p /opt/elastalert && \
    cd /tmp/elastalert && \
    pip install setuptools wheel && \
    python setup.py sdist bdist_wheel

FROM python:3-slim-buster

ARG GID=1000
ARG UID=1000
ARG USERNAME=elastalert

COPY --from=builder /tmp/elastalert/dist/*.tar.gz /tmp/

RUN apt update && apt -y upgrade && \
    apt -y install jq curl gcc libffi-dev && \
    rm -rf /var/lib/apt/lists/* && \
    pip install /tmp/*.tar.gz && \
    rm -rf /tmp/* && \
    apt -y remove gcc libffi-dev && \
    apt -y autoremove && \
    mkdir -p /opt/elastalert && \
    echo "#!/bin/sh" >> /opt/elastalert/run.sh && \
    echo "set -e" >> /opt/elastalert/run.sh && \
    echo "elastalert-create-index --config /opt/elastalert/config.yaml" \
        >> /opt/elastalert/run.sh && \
    echo "elastalert --config /opt/elastalert/config.yaml \"\$@\"" \
        >> /opt/elastalert/run.sh && \
    chmod +x /opt/elastalert/run.sh && \
    groupadd -g ${GID} ${USERNAME} && \
    useradd -u ${UID} -g ${GID} -M -b /opt -s /sbin/nologin \
        -c "ElastAlert 2 User" ${USERNAME}

USER ${USERNAME}
ENV TZ "UTC"

WORKDIR /opt/elastalert
# Copy the config.yaml file to the appropriate location
COPY config.yaml /opt/elastalert/config.yaml
# Copy certificate files to the image
#RUN mkdir -p /opt/elastalert/certs
COPY --chown=${USERNAME}:${USERNAME} certs /opt/elastalert/

ENTRYPOINT ["/opt/elastalert/run.sh"]
