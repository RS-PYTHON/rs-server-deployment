#!/bin/bash
# Copyright 2023-2026 Airbus, CS Group
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

APPS="${APPS_DIR:-rs-server-deployment/apps}"

RS_VALUES_FILES=(
  "${APPS}/02-rs-server-osam/values.yaml"
  "${APPS}/rs-dpr-service-py-3-13-18-dask-2026-7-1/values.yaml"
  "${APPS}/rs-server-adgs/values.yaml"
  "${APPS}/rs-server-cadip/values.yaml"
  "${APPS}/rs-server-catalog/values.yaml"
  "${APPS}/rs-server-frontend/values.yaml"
  "${APPS}/rs-server-prip/values.yaml"
  "${APPS}/rs-server-staging/values.yaml"
)

# Lower the CPU/memory requests
# Minimum memory for postgresql must be > shared_buffers, which is 1/4 of the total ram
sed -i -e 's!instances: 3!instances: 1!g' -e 's!storage: 8!storage: 1!g' "${APPS}/01-cloudnative-pgstac/cluster.yaml"
sed -i -e 's!cpu: "100m"!cpu: "1m"!g' -e 's!ram: "256Mi"!ram: "10Mi"!g' "${APPS}"/mockup-*/values.yaml || echo "no mockup found"
sed -i -e 's!cpu: "100m"!cpu: "10m"!g' -e 's!ram: "256Mi"!ram: "32Mi"!g' "${RS_VALUES_FILES[@]}"

# For a pull request, use the RS docker images built for the source branch, if they exist,
# instead of the docker images from the released helm charts.
if [[ -n "${PR_BRANCH_NAME:-}" ]]; then
  # Docker tag = branch name in lowercase, with special characters replaced by '-'
  branch_tag="${PR_BRANCH_NAME,,}"
  branch_tag="${branch_tag//[^a-z0-9._-]/-}"
  for file in "${RS_VALUES_FILES[@]}"; do
    # Image name: from the values file, else the helm chart name (same as the image name)
    name=$(awk '/^image:/{p=1;next} p&&/^[^ #]/{p=0} p&&/^ +name:/{print $2; exit}' "${file}")
    [[ -z "${name}" ]] && name=$(sed -n "s/^- name: //p" "$(dirname "${file}")/kustomization.yaml" | head -1)
    image="ghcr.io/rs-python/${name}:${branch_tag}"
    if docker manifest inspect "${image}" > /dev/null 2>&1; then
      echo "Use '${image}'"
      if grep -q "^image:" "${file}"; then
        # Replace the image version in the existing 'image:' block
        awk -v tag="${branch_tag}" '
          /^image:/ {print; print "  version: \"" tag "\""; p=1; next}
          p && /^[^ #]/ {p=0}
          p && /^  version:/ {next}
          {print}' "${file}" > "${file}.tmp"
        mv "${file}.tmp" "${file}"
      else
        printf '\nimage:\n  version: "%s"\n' "${branch_tag}" >> "${file}"
      fi
    else
      echo "Use the default '${name}' image from the helm chart"
    fi
  done
fi

if [[ "${DEPLOY_MONITORING:-true}" = "false" ]]; then
  # Remove the "Wait for Alloy" init container in RS applications if monitoring is not deployed
  for file in "${RS_VALUES_FILES[@]}"; do
    if grep -q "^initContainers:" "${file}"; then
      sed -i 's/initContainers:/disabled:/g' "${file}"
    fi
  done
fi
