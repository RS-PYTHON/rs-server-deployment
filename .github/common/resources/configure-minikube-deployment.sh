#!/bin/bash
# Copyright 2025 CS Group
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

# Lower the CPU/memory requests
# Minimum memory for postgresql must be > shared_buffers, which is 1/4 of the total ram
sed -i -e 's!instances: 3!instances: 1!g' -e 's!cpu: "1"!cpu: "0.1"!g' -e 's!memory: "2G"!memory: "256M"!g' -e 's!memory: "1024M"!memory: "100M"!g' "${APPS}/01-eo-cnpgstac/values.yaml"
sed -i -e 's!cpu: "100m"!cpu: "1m"!g' -e 's!ram: "256Mi"!ram: "10Mi"!g' ${APPS}/mockup-*/values.yaml || echo "no mockup found"
sed -i -e 's!cpu: "100m"!cpu: "10m"!g' -e 's!ram: "256Mi"!ram: "32Mi"!g'\
  "${APPS}/rs-dpr-service/values.yaml"\
  "${APPS}/rs-server-adgs/values.yaml"\
  "${APPS}/rs-server-cadip/values.yaml"\
  "${APPS}/rs-server-catalog/values.yaml"\
  "${APPS}/rs-server-frontend/values.yaml"\
  "${APPS}/rs-server-prip/values.yaml"\
  "${APPS}/rs-server-staging/values.yaml"
