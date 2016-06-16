function get_secrets() {
  conf_name="${1}"
  conf_file="${SECRETS_DIR}/${conf_name}"
  if [ -f ${conf_file} ]; then
    echo "Using config from ${conf_file}"
    value="$(cat ${conf_file})"
  else
    value=""
  fi
  if [ ! -z ${value} ]; then
    eval "export ${conf_name}=${value}"
  fi
}

function get_hostname() {
    # if in a pod, set IP to the pod IP, otherwise
    # set it to the hostname
    IP=${POD_IP:-}
    NODE_ID=${NODE:-}
    if [[ -z "${IP}" ]]; then
        echo "no pods\n"
        export DOCKER_IP=$(hostname --ip-address)
        export HNAME=$(hostname)
        echo "$DOCKER_IP $NODE_ID"
    else
        export DOCKER_IP=$($IP)
        export HNAME=$($POD_NAME)
    fi
    export NODE=${HNAME//[^a-z0-9]/_}
}

function fix_ca() {
    FILE=${CA_FILE:-}
    if [[ -n ${FILE} ]]; then
        echo "Checking CA File: ${FILE}"
        [ ! -f ${FILE} ] && echo "Missing cert file specified ${FILE}:"
        cp ${FILE} /etc/pki/ca-trust/source/anchors/
        update-ca-trust
    fi
}