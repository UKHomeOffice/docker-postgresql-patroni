#!/bin/bash -eux

function usage()
{
    cat <<__EOF__
Usage: $0

Options:

    --etcd      ETCD    Provide an external etcd to connect to
    --name      NAME    Give the cluster a specific name
    --etcd-only         Do not run Patroni, run a standalone etcd

Examples:

    $0 --etcd=127.17.0.84
    $0 --etcd-only
    $0
    $0 --name=true_scotsman
__EOF__
}

if [ -f /srv/functions/functions.sh ]; then
    source /srv/functions/functions.sh
fi

export PATRONI_SCOPE=${PATRONI_SCOPE:-batman}

get_hostname

if [ -f /srv/etc/environment ]; then
    source /srv/etc/environment
fi 

echo "Setting up haproxy confd template"
/etc/confd/conf.d/haproxy.toml.sh

for file in ${SECRETS_DIR}/* ; do
  get_secrets $(basename ${file})
done

optspec=":vh-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                etcd-only)
                    exec etcd --data-dir /tmp/etcd.data \
                        -advertise-client-urls=${ETCD_PROTOCOL}://${DOCKER_IP}:4001 \
                        -listen-client-urls=${ETCD_PROTOCOL}://0.0.0.0:4001 \
                        -listen-peer-urls=${ETCD_PROTOCOL}://0.0.0.0:2380
                    exit 0
                    ;;
                cheat)
                    export CHEAT=1
                    ;;
                name)
                    export PATRONI_SCOPE="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                name=*)
                    export PATRONI_SCOPE=${OPTARG#*=}
                    ;;
                etcd)
                    export ETCD_CLUSTER="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                etcd=*)
                    export ETCD_CLUSTER=${OPTARG#*=}
                    ;;
                help)
                    usage
                    exit 0
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;
            esac;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
                usage
                exit 1
            fi
            ;;
    esac
done


if [ "$(whoami)" != "${PGUSER}" ]; then
  # Steps to carry out before switching to un-privileged user

  mkdir -p "${DATA_DIR}"
  echo "Fixing permissions..."
  chown -R ${PGUSER}:${PGUSER} "${DATA_DIR}"
  chmod -R 700 "${DATA_DIR}"

  echo "Adding CA..."
  fix_ca
fi

if [ -z ${ETCD_CLUSTER} ]
then
    gosu ${PGUSER} "etcd --data-dir /tmp/etcd.data \
        -advertise-client-urls=${ETCD_PROTOCOL}://${DOCKER_IP}:4001 \
        -listen-client-urls=${ETCD_PROTOCOL}://0.0.0.0:4001 \
        -listen-peer-urls=${ETCD_PROTOCOL}://0.0.0.0:2380 > /var/log/etcd.log 2>&1 &"
    export ETCD_CLUSTER="127.0.0.1"
fi

gosu ${PGUSER} mkdir -p ~postgres/.config/patroni
gosu ${PGUSER} envtpl /srv/etc/patronictl.json.tpl --keep-template --allow-missing -o ~postgres/.config/patroni/patronictl.json
gosu ${PGUSER} envtpl /srv/etc/patroni.yaml.tpl --keep-template --allow-missing -o /srv/etc/patroni.yaml
exec /srv/bin/update_haproxy &

if [ "$DEBUG" == "true" ]
then
	CONFD_OPTIONS+="-verbose=true -debug=true"
fi
exec confd -interval 10 -node ${ETCD_CLUSTER}:${ETCD_PORT} -scheme="${ETCD_PROTOCOL}" $CONFD_OPTIONS &

WAIT=${CHEAT:-}
if [ ! -z $WAIT ]
then
    while :
    do
        sleep 60
    done
else
    exec gosu ${PGUSER} patroni /srv/etc/patroni.yaml
fi
