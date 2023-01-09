#!/bin/bash

# Exit script on fail (use `|| true` if it's okay to fail).
# Based on https://stackoverflow.com/a/2871034/3017716
set -euo pipefail

# Based on https://unix.stackexchange.com/a/204927
while [ $# -gt 0 ]; do
    case "$1" in
        --prod)
            # Because forge deployment does not use .bashrc, see https://github.com/nvm-sh/nvm#git-install.
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
            [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

            nvm use 16
            ;;
        *)
            printf "***************************\n"
            printf "* Error: Invalid argument.*\n"
            printf "***************************\n"
            exit 1
    esac
    shift
done

# Print al (expanded) commands before executing (after `. nvm.sh` & `nvm use`).
set -x

export NODE_OPTIONS=--max_old_space_size=2048 # 2GB

# Not running `make assets` we don't have to build admin-default, admin-new-theme & front-classic every time.
make front-core

wd=$(pwd)

#cd "$wd/modules/mollie"
#npm install
#npm run build

cd "$wd/themes/falcon/_dev"
npm install
npm run build
