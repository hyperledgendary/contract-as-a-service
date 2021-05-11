#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
set -euo pipefail
: ${CORE_PEER_TLS_ENABLED:="false"}

if [ "${CORE_PEER_TLS_ENABLED,,}"  = "true" ]; then
    npm run start:server
else
    npm run start:server-nontls
fi
