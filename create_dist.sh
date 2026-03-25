#!/bin/bash

#
# In case you have never used npm do
#
# npm install
#

CURR_DIR=$(pwd)

branch_name=`git branch | head | cut -d ' ' -f 2 | tail -n 1`

echo "-- Cleaning up dist -- "
cd httpdocs/dist
git fetch
git checkout $branch_name
git reset --hard @{u}

echo "-- Compiling dist -- "
cd $CURR_DIR
npm run build || exit 1

echo "-- Pushing dist --"
cd httpdocs/dist
git add *
git commit -m 'Update dist' || exit 1
git push || exit 1

echo "-- Pushing ref --"
cd $CURR_DIR
git add httpdocs/dist
git commit -m 'Update dist' || exit 1
git push || exit 1

echo "Dist up to date"
