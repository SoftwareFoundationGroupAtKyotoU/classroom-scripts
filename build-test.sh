#!/bin/bash

usage-exit() {
    echo "Usage: $0 [-h] [-i] TARGET" >&2
    exit 1
}
error() {
    echo Error: "$@" >&2
    return 1
}
ensure-env() {
    local var= err= msg=
    for var in "$@"; do
        if [[ -z "${!var+set}" ]]; then
            msg="environment variable '$var' is unset"
            error "$msg" || err=on
        fi
    done
    [[ -z "$err" ]] || exit 1
}
ensure-cmd() {
    local cmd= err= msg=
    for cmd in "$@"; do
        if ! which "$cmd" &>/dev/null; then
            msg="command '$cmd' not found"
            error "$msg" || err=on
        fi
    done
    [[ -z "$err" ]] || exit 1
}

join() {
    local delim=' ' arg= args=()
    while ((0 < $#)); do
        arg="$1" && shift
        case "$arg" in
            -d) delim="$1" && shift;;
            -*) error "unknown option '$arg'" || exit 1;;
            *) args+=("$arg");;
        esac
    done
    set -- "${args[@]}"
    if ((0 < $#)); then
        echo -n "$1" && shift
    fi
    for arg in "$@"; do
        echo -n "$delim$arg"
    done
    echo
}
quote() {
    local conv=$(echo -n "$1" | hexdump -ve '/1 "{%02x}"')
    local scripts=(-e 's/{5c}/{5c}{5c}/g')
    conv=$(echo -n "$conv" | sed "${scripts[@]}")
    scripts=()
    scripts+=(-e 's/{08}/{5c}{62}/g')
    scripts+=(-e 's/{09}/{5c}{74}/g')
    scripts+=(-e 's/{0a}/{5c}{6e}/g')
    scripts+=(-e 's/{0c}/{5c}{66}/g')
    scripts+=(-e 's/{0d}/{5c}{72}/g')
    scripts+=(-e 's/{22}/{5c}{22}/g')
    scripts+=(-e 's/{2f}/{5c}{2f}/g')
    conv=$(echo -n "$conv" | sed "${scripts[@]}")
    scripts=(-e 's/{\(..\)}/\\x\1/g')
    conv=$(echo -n "$conv" | sed "${scripts[@]}")
    echo -e '"'"$conv"'"'
}
json() {
    local key= value= data=()
    while ((0 < $#)); do
        key=$(quote "$1") && shift
        value=$(quote "$1") && shift
        data+=("$key: $value")
    done
    data=$(join -d ', ' "${data[@]}")
    echo "{ $data }"
}

traverse() {
    if [[ -d "$1" ]]; then
        pushd "$1" >&$PUSHLOG
        if [[ -d .git ]]; then
            process
        else
            local repo
            ls | while read repo; do
                traverse "$PWD/$repo"
            done
        fi
        popd >&$POPLOG
    fi
}
process() {
    local head=$(git rev-parse HEAD)
    local stderr=
    if [[ "$head" != "$INITIAL_COMMIT_HASH" ]]; then
        if git-diff java; then
            if stderr=$(build-java); then
                post-java-message "$stderr"
                pwd >&$JAVAERR
            fi
        fi
        if git-diff ocaml; then
            if stderr=$(build-ocaml); then
                post-ocaml-message "$stderr"
                pwd >&$OCAMLERR
            fi
        fi
        if ! git-diff report.md; then
            post-report-message
            pwd >&$REPORTERR
        fi
    fi
}
git-diff() {
    local diff=$(git diff --stat --name-only "$INITIAL_COMMIT_HASH" -- "$1")
    [[ -n "$diff" ]]
}
post-message() {
    local head=$(git rev-parse HEAD)
    local version=$(eval "${2:2}")
    local code='```'
    local msg=(Please fix your source files and tell us the new SHA
               to be graded by adding a new comment to this issue.)
    cat <<EOF
$1 on $head has *FAILED*.
${msg[*]}
$code console
$2
$version
$3
$code
EOF
}
post-java-message() {
    local title=(Compilation of Java sources has failed)
    local version=('$' javac --version)
    local args=("${title[*]:0:4}" "${version[*]}" "$1")
    post-message "${args[@]}" | post "${title[*]}"
}
post-ocaml-message() {
    local title=(Compilation of OCaml sources has failed)
    local version=('$' ocamlopt --version)
    local args=("${title[*]:0:4}" "${version[*]}" "$1")
    post-message "${args[@]}" | post "${title[*]}"
}
post-report-message() {
    local report='`report.md`'
    local title=(No information 'in' your report.md)
    local msg1=(You must write appropriate information 'in' "$report".)
    local msg2=(Please fix your "$report" file and tell us the new SHA
                to be graded by adding a new comment to this issue.)
    cat <<EOF | post "${title[*]}"
${msg1[*]}
${msg2[*]}
EOF
}
copy-to-tmp() {
    if [[ -d "$1" ]]; then
        local tmp=/tmp
        local base=$(basename "$PWD")
        local dir=$(basename "${PWD%/*}")
        tmp+="/$dir"
        mkdir -p "$tmp"
        tmp+="/$base-$1"
        [[ -e "$tmp" ]] && rm -r "$tmp"
        cp -r "$1" "$tmp"
        chmod -R +w "$tmp"
        echo "$tmp"
    else
        error "Not found '$PWD/$1'"
    fi
}
build-java() {
    local tmp= err=1
    if tmp=$(copy-to-tmp java); then
        pushd "$tmp" >&$PUSHLOG
        convert-format .java
        local cmds=(javac $(ls *.java | grep -v -e 'Test.\.java'))
        echo '$' "${cmds[@]}"
        eval "${cmds[@]}" 2>&1 >/dev/null || err=0
        popd >&$POPLOG
    fi
    return $err
}
build-ocaml() {
    local tmp= err=1
    if tmp=$(copy-to-tmp ocaml); then
        pushd "$tmp" >&$PUSHLOG
        convert-format .ml
        local cmds=(ocamlopt tree.ml testcase.ml)
        echo '$' "${cmds[@]}"
        eval "${cmds[@]}" 2>&1 >/dev/null || err=0
        popd >&$POPLOG
    fi
    return $err
}
convert-format() {
    local file=
    find . -name "*$1" | while read file; do
        nkf -wLu --overwrite "$file"
    done
}
post() {
    local title="$1"
    local body=$(cat -)
    local data=$(json title "$title" body "$body")
    local user=$(basename "$PWD")
    local org="$CLASSROOM_ORGANIZATION"
    local repo="${CLASSROOM_REPOSITORY}-${user}"
    local url="https://api.github.com/repos/$org/$repo/issues"
    local type='Content-Type: application/json'
    local auth="Authorization: token $GITHUB_ACCESS_TOKEN"
    if [[ -z "$ISSUE" ]]; then
        printf '%s\n' curl -H "$type" -H "$auth" -d "$data" "$url" >&$COMPILELOG
    else
        curl -H "$type" -H "$auth" -d "$data" "$url"
    fi
}

LC_MESSAGES=C
ISSUE=
ENVVARS=(INITIAL_COMMIT_HASH
         GITHUB_ACCESS_TOKEN
         CLASSROOM_ORGANIZATION
         CLASSROOM_REPOSITORY)
COMMANDS=(javac ocamlopt hexdump curl nkf)
ensure-env "${ENVVARS[@]}"
ensure-cmd "${COMMANDS[@]}"
if [[ -n "${DEBUG:-}" ]]; then
    exec {ALLLOG}>all.log
    exec {BASH_XTRACEFD}> >(tee xtrace.log >&$ALLLOG)
    set -ux
    exec {PUSHLOG}> >(tee push.log >&$ALLLOG)
    exec {POPLOG}> >(tee pop.log >&$ALLLOG)
    exec {COMPILELOG}> >(tee compile.log >&$ALLLOG)
    exec {JAVAERR}>java-err.log
    exec {OCAMLERR}>ocaml-err.log
    exec {REPORTERR}>report-err.log
    exec {DEBUGLOG}>debug.log
else
    exec {PUSHLOG}>/dev/null
    exec {POPLOG}>/dev/null
    exec {COMPILELOG}>/dev/null
    exec {JAVAERR}>/dev/null
    exec {OCAMLERR}>/dev/null
    exec {REPORTERR}>/dev/null
    exec {DEBUGLOG}>/dev/null
fi
while getopts hi OPT; do
    case "$OPT" in
        h|'?') usage-exit;;
        i) ISSUE=on;;
    esac
done
shift $((OPTIND - 1))
if [[ -z "${1+set}" ]]; then
    error 'argument TARGET is unset'
    usage-exit
else
    traverse "$1"
fi
