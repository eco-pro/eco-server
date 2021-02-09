FROM rupertlssmith/buster_elm19:v1
MAINTAINER Rupert Smith, https://github.com/rupertlssmith

# install main packages:
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install python3 python-dev python-pip -y && \
    apt-get clean

RUN pip install awscli

WORKDIR /tmp/workdir

COPY build_elm.py /tmp/workdir

ENTRYPOINT ./build_elm.py
