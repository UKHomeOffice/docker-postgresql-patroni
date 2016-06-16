## This Dockerfile is meant to aid in the building and debugging patroni whilst developing on your local machine
## It has all the necessary components to play/debug with a single node appliance, running etcd
FROM quay.io/ukhomeofficedigital/centos-base:latest
MAINTAINER Feike Steenbergen <feike.steenbergen@zalando.de>

ENV LOCALE en_GB.UTF-8
ENV PGVERSION 9.5
ENV PGVERSION_SHORT 95
ENV PGRPM_MINOR 2
ENV ETCDVERSION 2.2.5
ENV GOSU_VERSION 1.9
ENV BASE_DIR /srv
ENV BIN_DIR  ${BASE_DIR}/bin
ENV ETC_DIR  ${BASE_DIR}/etc
ENV DATA_DIR ${BASE_DIR}/data
ENV FUNCTIONS_DIR  ${BASE_DIR}/functions
ENV LIB_DIR  ${BASE_DIR}/lib
ENV SECRETS_DIR /secrets
ENV ETCD_PROTOCOL http
ENV ETCD_PORT 4001
ENV PGUSER postgres
ENV GOPATH /opt/go
ENV HAPROXY_KEY haproxy_pgsql
ENV PATH ${BASE_DIR}/bin:/usr/pgsql-${PGVERSION}/bin:$GOPATH/bin:$PATH

RUN mkdir -p                     \
        ${BASE_DIR}/wal-e.d/     \
        ${BIN_DIR}               \
        ${ETC_DIR}               \
        ${DATA_DIR}              \
        ${FUNCTIONS_DIR}         \
        ${LIB_DIR}               \
        ${SECRETS_DIR}           \
        ${GOPATH}

ADD etc/ ${ETC_DIR}
ADD functions/ ${FUNCTIONS_DIR}
ADD bin/ ${BIN_DIR}
    
RUN rpm -Uvh https://download.postgresql.org/pub/repos/yum/${PGVERSION}/redhat/rhel-7-x86_64/pgdg-centos${PGVERSION_SHORT}-${PGVERSION}-${PGRPM_MINOR}.noarch.rpm
RUN yum install -y epel-release

RUN yum install -y \
        postgresql${PGVERSION_SHORT} \
        postgresql${PGVERSION_SHORT}-server \
        postgresql${PGVERSION_SHORT}-contrib \
        postgresql${PGVERSION_SHORT}-devel \
        postgresql${PGVERSION_SHORT}-libs \
        python-psycopg2 \
        readline-devel \
        hostname \
        python \
        python-devel \
        python-pip \
        ca-certificates \
        openssl \
        openssl-devel \
        haproxy

RUN test "$(id postgres)" = "uid=26(postgres) gid=26(postgres) groups=26(postgres)"

RUN pip install --upgrade \
        pip               \
        setuptools

RUN pip install           \
        wheel             \
        envtpl            \
        mock              \
        dnspython

ADD requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

RUN curl -#L "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64"  -o /bin/gosu && \
    curl -#L "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64.asc" -o  /tmp/gosu.asc && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /tmp/gosu.asc /bin/gosu && \
    rm -r "$GNUPGHOME" /tmp/gosu.asc && \
    chmod +x /bin/gosu
    
ADD patroni.py ${BASE_DIR}/lib/patroni.py
ADD patronictl.py ${BASE_DIR}/lib/patronictl.py
ADD patroni/ ${BASE_DIR}/lib/patroni

RUN ln -s ${BASE_DIR}/lib/patroni.py ${BASE_DIR}/bin/patroni
RUN ln -s ${BASE_DIR}/lib/patronictl.py ${BASE_DIR}/bin/patronictl

RUN curl -#L https://github.com/coreos/etcd/releases/download/v${ETCDVERSION}/etcd-v${ETCDVERSION}-linux-amd64.tar.gz | tar xz -C /bin --strip=1 --wildcards --no-anchored etcd etcdctl

RUN curl -#L https://github.com/kelseyhightower/confd/releases/download/v0.7.1/confd-0.7.1-linux-amd64 -o /bin/confd && \
    chmod +x /bin/confd && \
    mkdir -p /etc/confd/conf.d /etc/confd/templates

ADD etc/haproxy.cfg.tpl /etc/confd/templates/haproxy.tmpl
ADD etc/haproxy.toml /etc/confd/conf.d/haproxy.toml

### Setting up a simple script that will serve as an entrypoint
RUN touch                        \ 
        /var/log/etcd.log        \
        /pgpass

RUN chown -R ${PGUSER}:${PGUSER} \
        ${BASE_DIR}              \
        /pgpass                  \
        /var/log/etcd.log        \
        /etc/confd 


### Make Dummy SSL Certs
RUN sh /etc/ssl/certs/make-dummy-cert /etc/ssl/certs/patroni.cert && \
    chown postgres:postgres /etc/ssl/certs/patroni.cert

ADD docker/entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /srv/bin/* /docker-entrypoint.sh

EXPOSE 4001 5432 2380
ENTRYPOINT ["/docker-entrypoint.sh"]
