#! /bin/bash -

# This script reads from stdin a list of github handles and clones submissions.

if [ -e ./local.sh ]; then
  . local.sh
else
  echo "local.sh is needed.  See local.sh.temp for variables to set."
  exit 1
fi

usage_exit() {
        echo "Usage: $0 [-h] [-k kadai] [-o organization]" 1>&2
        exit 1
}

while getopts k:h OPT
do
    case $OPT in
        k)  PREFIX=$OPTARG
            ;;
        o)  ORG=$OPTARG
            ;;
        h)  usage_exit
            ;;
        \?) usage_exit
            ;;
    esac
done

while read ST; do  # for each student (given from stdin)

    echo "Processing $ST" 1>&2

    if [ ! -d $PREFIX-$ST ]; then
        echo "Cloning $ST's repository" 1>&2
        git clone git@github.com:$ORG/$PREFIX-$ST.git
    fi

done
