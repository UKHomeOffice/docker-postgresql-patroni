---
scope: &scope {{ CLUSTER }}
ttl: &ttl 30
loop_wait: &loop_wait 10
restapi:
  listen: {{ DOCKER_IP }}:8001
  connect_address: {{ DOCKER_IP }}:8001
  auth: '{{ APIUSER }}:{{ APIPASS }}'
  certfile: /etc/ssl/certs/patroni.cert
  keyfile: /etc/ssl/certs/patroni.cert
etcd:
  scope: *scope
  ttl: *ttl
  host: {{ ETCD_CLUSTER }}:{{ ETCD_PORT }}
  protocol: {{ ETCD_PROTOCOL }}
tags:
  nofailover: False
  noloadbalance: False
  clonefrom: False
postgresql:
  name: {{ NODE }}
  scope: *scope
  listen: 0.0.0.0:5432
  connect_address: {{ DOCKER_IP }}:5432
  data_dir: {{ DATA_DIR }}
  maximum_lag_on_failover: 104857600 # 100 megabyte in bytes
  use_slots: True
  pgpass: /tmp/pgpass0
  initdb:
  - encoding: UTF8
  - data-checksums
  create_replica_methods:
  - basebackup
  pg_hba:
  - host all all 0.0.0.0/0 md5
  - host replication {{ ADMINUSER }} {{ DOCKER_IP }}/16 md5
  replication:
    username: {{ ADMINUSER }}
    password: {{ ADMINPASS }}
    network:  {{ DOCKER_IP }}/16
  pg_rewind:
    username: {{ ADMINUSER }}
    password: {{ ADMINPASS }}
  superuser:
    username: {{ ADMINUSER }}
    password: {{ ADMINPASS }}
  admin:
    username: {{ ADMINUSER }}
    password: {{ ADMINPASS }}
  parameters:
    archive_mode: "off"
    # archive_command: 'true'
    listen_addresses: 0.0.0.0
    archive_command: mkdir -p ../wal_archive && cp %p ../wal_archive/%f
    wal_level: hot_standby
    max_wal_senders: 10
    hot_standby: "on"
    max_replication_slots: 7
    wal_keep_segments: 5
