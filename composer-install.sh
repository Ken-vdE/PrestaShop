#!/bin/bash

# Exit script on fail (use `|| true` if it's okay to fail).
# Print al (expanded) commands before executing.
# Based on https://stackoverflow.com/a/2871034/3017716
set -euxo pipefail

# For $FORGE_COMPOSER e.g. "php8.1 /usr/local/bin/composer" or "php /opt/homebrew/bin/composer"
composer=${1:-composer}
composerArgs=""

# Based on https://unix.stackexchange.com/a/204927
while [ $# -gt 0 ]; do
    case "$1" in
        --prod)
            composerArgs="--no-dev --no-interaction --prefer-dist --optimize-autoloader"
            ;;
        --composer=*)
            composer="${1#*=}"
            ;;
        *)
            printf "***************************\n"
            printf "* Error: Invalid argument.*\n"
            printf "***************************\n"
            exit 1
    esac
    shift
done

$composer install $composerArgs

wd=$(pwd)

cd "$wd/modules/mollie"
$composer install $composerArgs

cd "$wd/modules/is_themecore"
$composer install $composerArgs

cd "$wd/modules/is_imageslider"
$composer install $composerArgs

cd "$wd/modules/is_searchbar"
$composer install $composerArgs

cd "$wd/modules/is_shoppingcart"
$composer install $composerArgs
