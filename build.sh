#! /bin/bash - 

CLASSPATH=$PWD/objectdraw-ku20180313.jar
REPO=`basename $PWD`
GENMAIN="$(cd $(dirname $0);pwd)/genMain.sh"
ASSIGNEE=""
REV=`git log submission --pretty=format:"%h" -n 1`

if [ -e ./local.sh ]; then
  . local.sh
else
  echo "local.sh is needed.  See local.sh.temp for variables to set."
  exit 1
fi

usage_exit() {
        echo "Usage: $0 [-h] [-t token] [-i] [-c class path] [-a assignee]" 1>&2
        exit 1
}

while getopts c:t:k:ia:h OPT
do
    case $OPT in
        t)  TOKEN=$OPTARG
            ;;
        c)  CLASSPATH=$OPTARG
            ;;
        i)  ISSUE=1
            ;;
        a)  ASSIGNEE=$OPTARG
            ;;
        h)  usage_exit
            ;;
        \?) usage_exit
            ;;
    esac
done

echo "Compiling:" *.java 1>&2

git checkout -f $REV

if javac -cp $CLASSPATH *.java; then
    echo "Build succeeded!" 1>&2
    if ((${ISSUE})) && [[ $ASSIGNEE != "" ]]; then
        echo "Creating an issue..." 1>&2
        curl -H "Content-Type: application/json" \
             -H "Authorization: token $TOKEN" \
             --data "{\"title\": \"Grading has started\", \"assignees\" : [\"$ASSIGNEE\"], \"body\": \"Compilation of $REV has succeeded.  Watch this issue until grading ends.\" }" \
             https://api.github.com/repos/$ORG/$REPO/issues
    fi
else
    echo "Build failed ;-("
    if ((${ISSUE})) && [[ $ASSIGNEE != "" ]]; then
        echo "Creating an issue..." 1>&2
        curl -H "Content-Type: application/json" \
             -H "Authorization: token $TOKEN" \
             --data "{\"title\": \"Grading has started\", \"assignees\" : [\"$ASSIGNEE\"], \"body\": \"Compilation of $REV has FAILED.  Please fix your source files and tell us the new SHA to be graded by adding a new comment to this issue.\" }" \
             https://api.github.com/repos/$ORG/$REPO/issues
    fi
fi
