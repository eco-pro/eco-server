FROM rupertlssmith/buster_elm19:v1
MAINTAINER Rupert Smith, https://github.com/rupertlssmith

# install main packages:
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean

WORKDIR /tmp/workdir

COPY build_elm.sh /tmp/workdir

ENTRYPOINT ./build_elm.sh
