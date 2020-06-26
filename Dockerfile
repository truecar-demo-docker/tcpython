FROM python:3.6.8-slim

ARG USER=python
ARG UID=999
ARG PRECACHEPKGS="boto3 numpy pandas"

RUN \
  echo "deb http://deb.debian.org/debian stretch-backports main" \
    > /etc/apt/sources.list.d/backports.list \
  && LC_ALL=C apt-get update -yqq && LC_ALL=C apt-get dist-upgrade -yqq \
  && LC_ALL=C apt-get install -yqq --no-install-recommends \
    curl \
    make \
    unzip \
    zip \
    gnupg \
  && LC_ALL=C apt-get -t stretch-backports install -yqq --no-install-recommends \
    git \
  && useradd \
    --create-home \
    --home-dir /app \
    --skel /dev/null \
    --shell /bin/false \
    --uid ${UID} -U ${USER} \
  && mkdir /var/cache/venv \
  && chown ${UID}:${UID} /var/cache/venv \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /usr/share/man \
    /usr/share/doc \
    /usr/share/doc-base

USER ${USER}

WORKDIR /app

# entrypoint activates virtual environment
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN python -m venv /var/cache/venv && /usr/local/bin/entrypoint.sh \
    pip install --upgrade \
      pip \
      awscli \
      s3pypi \
      setuptools \
      git+https://git.corp.tc/python/tcpysetup@master \
      git+https://git.corp.tc/python/tcpylib@master \
      ${PRECACHEPKGS}

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
