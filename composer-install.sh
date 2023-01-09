#!/bin/bash

#set -e
#set -o pipefail
# Print al (expanded) commands before executing
set -x


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

#pwd
$composer install $composerArgs || exit $?

wd=$(pwd)

cd "$wd/modules/is_themecore" || exit $?
#pwd
$composer install $composerArgs || exit $?

cd "$wd/modules/is_imageslider" || exit $?
#pwd
$composer install $composerArgs || exit $?

cd "$wd/modules/is_searchbar" || exit $?
#pwd
$composer install $composerArgs || exit $?

cd "$wd/modules/is_shoppingcart" || exit $?
#pwd
$composer install $composerArgs || exit $?
