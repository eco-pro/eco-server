FROM rupertlssmith/buster_elm19:v1
MAINTAINER Rupert Smith, https://github.com/rupertlssmith

# install main packages:
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install python3 python3-dev python3-pip -y && \
    apt-get install wget locales -y && \
    apt-get clean

WORKDIR /tmp/workdir

# Install Python stuff.
RUN pip3 install boto3 requests python-dotenv

# Install mitmproxy
# Make sure default locale is set up or mitmproxy will complain about
# char encoding errors.
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN wget https://snapshots.mitmproxy.org/6.0.2/mitmproxy-6.0.2-linux.tar.gz
RUN tar -zxf mitmproxy-6.0.2-linux.tar.gz

# Install the mitmproxy CA certificate
COPY gencert /tmp/workdir
RUN ./gencert

# Ensure Elm 0.19.0 and 0.19.1 are on the path.
ENV PATH /usr/local/bin:$PATH

# Copy in the build worker scripts
COPY worker /tmp/workdir
COPY locate_services.py /tmp/workdir
COPY build_elm.py /tmp/workdir

# Run some build jobs
ENTRYPOINT ./worker
