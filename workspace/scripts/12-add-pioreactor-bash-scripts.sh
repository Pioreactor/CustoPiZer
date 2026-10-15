#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


# Same additive payload as release upgrades: does not select a role or enable services.
bash /files/common-assets/install_common_assets.sh /files/common-assets
