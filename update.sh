#!/bin/sh
# Note that currently development is done in uc_tools.
# This repository is just a wrapper for convenient packaging.
# Modeled after elfutils-lua/update.sh
set -e
cd $(dirname $0)
UC_TOOLS=/i/exo/uc_tools
for file in \
lua/lure/*.lua \

do
    here_file=$(basename $file)
    echo $here_file
    cp -a $UC_TOOLS/$file .
    git add $here_file
done
git commit -am 'update from uc_tools'
git push
git push origin HEAD:main
