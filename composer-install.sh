#!/bin/bash

#set -e
#set -o pipefail

pwd || exit $?
composer install || exit $?

wd=$(pwd) || exit $?

cd "$wd/modules/is_themecore" || exit $?
pwd || exit $?
composer install || exit $?

cd "$wd/modules/is_imageslider" || exit $?
pwd || exit $?
composer install || exit $?

cd "$wd/modules/is_searchbar" || exit $?
pwd || exit $?
composer install || exit $?

cd "$wd/modules/is_shoppingcart" || exit $?
pwd || exit $?
composer install || exit $?
