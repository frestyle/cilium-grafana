#!/bin/bash
set -o errexit
export KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-review-env}"


# create registry container unless it already exists
reg_name='kind-registry'
reg_port='5000'


running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

