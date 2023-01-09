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

# Exit script on fail (use `|| true` if it's okay to fail).
# Print al (expanded) commands before executing (after `. nvm.sh`).
# Based on https://stackoverflow.com/a/2871034/3017716
set -euxo pipefail

cd /home/everwaresportscom
mainDir=$(pwd)

# Delete previously failed deployments.
# Based on https://unix.stackexchange.com/a/245287/340752 and https://stackoverflow.com/a/13032768/3017716
find . -maxdepth 1 -type d -name "$(date +'%Y')[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]" -exec rm -rf {} +

# Create new deploy dir and cd into it.
dir=$(date +'%Y%m%d%H%M%S')
mkdir "$dir"
cd "$dir"


# Do deployment (based on https://devdocs.prestashop-project.org/8/basics/installation/localhost/).
git clone --branch $FORGE_SITE_BRANCH --depth 1 --recurse-submodules --shallow-submodules git@github.com:Ken-vdE/PrestaShop.git .
#git submodule update --init --recursive
rm -rf install-dev # For security

./composer-install.sh --composer="$FORGE_COMPOSER" --prod

cp "$mainDir/everwaresports.com-persistents/themes/falcon/_dev/webpack/.env" "$(pwd)/themes/falcon/_dev/webpack/.env"
./npm-install.sh --prod

mkdir log app/logs app/Resources/translations
#TODO ADMIN_DIR variable?
chmod -R +w admin-dev/autoupgrade app/config app/logs app/Resources/translations cache config download img log mails modules override themes translations upload var

persistentsDir="everwaresports.com-persistents"
#tar -zcvf "$persistentsDir.bak.tar.gz" "$persistentsDir/"
persistents=(
    # Directories
    "app/config/parameters.php"
    "app/config/parameters.yml"
    "config/defines_custom.inc.php"
    "config/settings.inc.php"
    # Files
    "admin-dev/themes/default" #TODO use $ADMIN_DIR
    "admin-dev/themes/new-theme" #TODO use $ADMIN_DIR
    "app/logs"
    "img"
    "mails"
    "translations"
    "upload"
    "var"
    "robots.txt"
)
for persistent in ${persistents[@]}; do
    freshlyClonedPersistentPath="$(pwd)/$persistent"
    actuallyStoredPersistentPath="$mainDir/$persistentsDir/$persistent"
    # Copy (new) git files to persistent stored directories.
    if [ -d "$freshlyClonedPersistentPath" ]; then
        # Note the / after source path (means put content of dir in target, not dir itself).
        rsync -a --mkpath "$freshlyClonedPersistentPath/" "$actuallyStoredPersistentPath"
    fi
    # Remove current item in new deployment (if exists) and add symlink to persistent stored item.
    if [ -e "$freshlyClonedPersistentPath" ]; then
        rm -rf "$freshlyClonedPersistentPath"
    fi
    ln -s "$actuallyStoredPersistentPath" "$freshlyClonedPersistentPath"
done


# Move back to main directory
cd ..
# Delete previous backup.
[ -d everwaresports.com.bak ] && rm -rf everwaresports.com.bak
# Backup previous deployment.
mv everwaresports.com everwaresports.com.bak
# Finalize and activate deployment.
mv "$dir" everwaresports.com

( flock -w 10 9 || exit 1
    echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock
