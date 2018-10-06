#! /bin/bash -

# This script creates labels.
# Run this script at each repository directory. 
# (example) createLabels.sh -t `cat ../token` -a (your name)

CMDNAME=`basename $0`
REPO=`basename $PWD`
ASSIGNEE=""

if [ -e ./local.sh ]; then
  . local.sh
else
  echo "local.sh is needed.  See local.sh.temp for variables to set."
  exit 1
fi

usage_exit() {
        echo "Usage: $CMDNAME [-h] [-t token] [-a assignee]" 1>&2
        exit 1
}

while getopts t:a:h OPT
do
    case $OPT in
        t)  TOKEN=$OPTARG
            ;;
        a)  ASSIGNEE=$OPTARG
            ;;
        h)  usage_exit
            ;;
        \?) usage_exit
            ;;
    esac
done



if [[ $ASSIGNEE != "" ]]; then
    echo "Adding labels..." 1>&2

    # 要再提出
    curl -X POST https://api.github.com/repos/$ORG/$REPO/labels \
         -u $ASSIGNEE:$TOKEN \
         -H "Accept: application/json" \
         -H "Content-type: application/json" \
         -d '{"name": "\u8981\u518d\u63d0\u51fa","color": "b60205"}'

    # 任意課題不備
    curl -X POST https://api.github.com/repos/$ORG/$REPO/labels \
         -u $ASSIGNEE:$TOKEN \
         -H "Accept: application/json" \
         -H "Content-type: application/json" \
         -d '{"name": "\u4efb\u610f\u8ab2\u984c\u4e0d\u5099","color": "fbca04"}'

    # 未提出
    curl -X POST https://api.github.com/repos/$ORG/$REPO/labels \
         -u $ASSIGNEE:$TOKEN \
         -H "Accept: application/json" \
         -H "Content-type: application/json" \
         -d '{"name": "\u672a\u63d0\u51fa","color": "5319e7"}'
else
    echo "Failed adding labels." 1>&2
fi

