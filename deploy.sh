#cd /home/your-user/your-site.com
#git pull origin $FORGE_SITE_BRANCH
#
#$FORGE_COMPOSER install --no-dev --no-interaction --prefer-dist --optimize-autoloader
#
#( flock -w 10 9 || exit 1
#    echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock

# Exit script on fail (use `|| true` if it's okay to fail).
# Print al (expanded) commands before executing (after `. nvm.sh`).
# Based on https://stackoverflow.com/a/2871034/3017716
set -euxo pipefail


cd "$FORGE_SITE_PATH" # /home/your-user/some-site.com

domain="${PWD##*/}" # some-site.com
cd ..
mainPath="$(pwd)" # /home/your-user


# Delete previously failed deployments.
# Based on https://unix.stackexchange.com/a/245287/340752 and https://stackoverflow.com/a/13032768/3017716
find . -maxdepth 1 -type d -name "$(date +'%Y')[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]" -exec rm -rf {} +


# Create new deploy dir and cd into it.
releaseDir=$(date +'%Y%m%d%H%M%S')
mkdir "$releaseDir"
cd "$releaseDir"


# Do deployment (based on https://devdocs.prestashop-project.org/8/basics/installation/localhost/).
git clone --branch "$FORGE_SITE_BRANCH" --depth 1 --recurse-submodules --shallow-submodules git@github.com:Ken-vdE/PrestaShop.git .


mkdir log app/logs app/Resources/translations
chmod -R +w admin-dev/autoupgrade app/config app/logs app/Resources/translations cache config download img log mails modules override themes translations upload var


./composer-install.sh --composer="$FORGE_COMPOSER" --prod

( flock -w 10 9 || exit 1
    echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock


# Modules use PHP and therefor can't use symlinked dirs (see comment at $persistents below).
# So rsync the the live modules dir into this new modules directory (only the dirs and files that don't exist yet).
# This way we keep the modules in an actual directory instead of symlinking it like $persistents below.
# We --ignore-existing so only subdirectories that don't exist yet in newly installed modules dir get copied.
# Note the / after source path (means put CONTENT of dir in target, don't put dir ITSELF in target).
# NOTE If you've deleted git submodules, those persist. So you have to delete those manually after a deployment.
rsync -a --mkpath --ignore-existing "$FORGE_SITE_PATH/modules/" "modules"


persistentsDirName="$domain-persistents"


cp "$mainPath/$persistentsDirName/themes/falcon/_dev/webpack/.env" "$(pwd)/themes/falcon/_dev/webpack/.env"
cp "$mainPath/$persistentsDirName/themes/falcon/_dev/js/sentry.js" "$(pwd)/themes/falcon/_dev/js/sentry.js"
./npm-install.sh --prod


# Note that PHP does not always play well with symlinked directories (or files?).
# E.g. using __DIR__ inside a php file that resides in a symlinked directory, returns the original directory
# instead of the symlinked directory that was used to include the php file.
# So make sure you're not symlinking directories (or files?) with complex PHP files in them.
# If so, there is a big chance Prestashop uses __DIR__ to include files and that breaks stuff.
persistents=(
    "admin-dev/themes/default"
    "admin-dev/themes/new-theme"
    "app/config/parameters.php"
    "app/config/parameters.yml"
    "app/logs"
    "config/defines_custom.inc.php"
    "config/settings.inc.php"
    "config/settings_custom.inc.php"
    "img"
    "mails"
    "robots.txt"
    "translations"
    "upload"
    "var/logs"
    "var/modules"
    "var/sessions"
)
for persistent in ${persistents[@]}; do
    freshlyClonedPersistentPath="$(pwd)/$persistent"
    actuallyStoredPersistentPath="$mainPath/$persistentsDirName/$persistent"
    # If is directory, rsync files to to persistent dir (creates dir if not exists).
    if [ -d "$freshlyClonedPersistentPath" ]; then
        # Note the / after source path (means put CONTENT of dir in target, don't put dir ITSELF in target).
        rsync -a --mkpath "$freshlyClonedPersistentPath/" "$actuallyStoredPersistentPath"
    # If is file and file does not yet exists in persistent storage, move (not copy for perf) to persistent storage.
    elif [ -f "$freshlyClonedPersistentPath" ] && [ ! -e "$actuallyStoredPersistentPath" ]; then
        mkdir -p "$actuallyStoredPersistentPath/.." # Make sure dir exists.
        mv "$freshlyClonedPersistentPath" "$actuallyStoredPersistentPath"
    fi

    # Remove current item in new deployment (if (still) exists) and add symlink to persistent stored item.
    if [ -e "$freshlyClonedPersistentPath" ]; then
        rm -rf "$freshlyClonedPersistentPath"
    fi
    ln -s "$actuallyStoredPersistentPath" "$freshlyClonedPersistentPath"
done


# Delete 'sensitive' unused files.
sensitives=(
    ".docker"
    ".github"
    "install-dev"
    ".editorconfig"
    ".php-cs-fixer.dist.php"
    "CODE_OF_CONDUCT.md"
    #"composer.json"
    #"composer.lock"
    #"composer-install.sh"
    "CONTRIBUTING.md"
    "CONTRIBUTORS.md"
    "deploy.sh"
    "docker-compose.yml"
    "INSTALL.txt"
    "LICENSE.md"
    #"Makefile"
    #"npm-install.sh"
    "phppsinfo.php"
    "phpstan.neon.dist"
    "README.md"
)
for sensitive in ${sensitives[@]}; do
    rm -rf "$sensitive"
done


# Based on `curl -sS "https://your-site.test/modules/gsitemap/gsitemap-cron.php?token=s0m3t0k3n&id_shop=1"`
$FORGE_PHP modules/gsitemap/gsitemap-cron.php


# Change the BackOffice path for security.
mv "admin-dev" "baasdingen"


# Run migrations etc.
#$FORGE_PHP modules/autoupgrade/upgrade/upgrade.php
#$FORGE_PHP modules/autoupgrade/cli-upgrade.php --dir=baasdingen --channel=minor
# Using cli-upgrade.php kind of does not work because the version pulled is already the newest version
# so the PrestashopConfiguration::getPrestaShopVersion() returns the new version and not the previous.
$FORGE_PHP bin/console prestashop:schema:update-without-foreign



# Move back to main directory
cd ..
# Delete previous backup.
[ -d "$domain.bak" ] && rm -rf "$domain.bak"
# Backup previous deployment.
mv "$domain" "$domain.bak"
# Finalize and activate deployment.
mv "$releaseDir" "$domain"


cd "$domain"
# If this crashes, just `rm var/cache/prod`.
$FORGE_PHP bin/console cache:clear --env=prod
