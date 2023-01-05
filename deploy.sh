#!/bin/bash

# Original:
#cd /home/everwaresportscom/everwaresports.com
#git pull origin $FORGE_SITE_BRANCH
#
#git submodule update --init --recursive
#
#$FORGE_COMPOSER install --no-dev --no-interaction --prefer-dist --optimize-autoloader
#
#( flock -w 10 9 || exit 1
#    echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock

# Print al (expanded) commands before executing
set -x

cd /home/everwaresportscom
mainDir=$(pwd)

# Delete previously failed deployments.
# Based on https://unix.stackexchange.com/a/245287/340752 and https://stackoverflow.com/a/13032768/3017716
find . -maxdepth 1 -type d -name "$(date +'%Y')[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]" -exec rm -r {} +

# Create new deploy dir and cd into it.
dir=$(date +'%Y%m%d%H%M%S')
mkdir "$dir"
cd "$dir"

# Do deployment.
git clone --branch $FORGE_SITE_BRANCH --depth 1 --recurse-submodules --shallow-submodules git@github.com:Ken-vdE/PrestaShop.git .
#git submodule update --init --recursive
# Based on https://devdocs.prestashop-project.org/8/basics/installation/localhost/
./composer-install.sh --composer="$FORGE_COMPOSER" --prod
make assets
npm run --prefix themes/falcon/_dev build
#TODO ADMIN_DIR variable?
chmod -R +w admin-dev/autoupgrade app/config app/logs app/Resources/translations cache config download img log mails modules override themes translations upload var

persistents=(
    "app/config/parameters.php"
    "app/config/parameters.yml"
    "config/defines_custom.inc.php"
    "config/settings.inc.php"
    "img"
    "mails"
    "translations"
    "upload"
    "var"
)
for persistent in ${persistent[@]}; do
    # Copy (new) git files to persistent stored directories.
    if [ -d "$(pwd)/$persistent" ]; then
        rsync -av "$(pwd)/$persistent" "$mainDir/everwaresports.com-persistens/$persistent"
    fi
    # Remove current item in new deployment and add symlink to persistent stored item.
    rm -r "$(pwd)/$persistent"
    ln -s "$mainDir/everwaresports.com-persistens/$persistent" "$(pwd)/$persistent"
done


# Move back to main directory.
cd ..

# Delete previous backup.
[ -d everwaresports.com.bak ] && rm -r everwaresports.com.bak
# Backup previous deployment.
mv everwaresports.com everwaresports.com.bak
# Finalize en activate deployment.
mv "$dir" everwaresports.com

#TODO add symlinks to persistent storage directories.

( flock -w 10 9 || exit 1
    echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock
