#! /bin/bash -

echo $@
while read DIR; do
    pushd $DIR
    git $@
    popd
done
