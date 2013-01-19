#!/bin/bash

set -e -u

usage () {
    echo "Usage: $0 [python|javascript|ruby|major|minor|revision]"
    echo "  Increment the revision number of one of the drivers or the major, minor"
    echo "  or revision number of rethinkdb itself (major.minor.revision)"
    exit 1
}

main () {
        cd "`git rev-parse --show-toplevel`"
        rethinkdb_full_version="`scripts/gen-version.sh`"
        rethinkdb_version="${rethinkdb_full_version%%-*}"
        rethinkdb_top_version="`top "$rethinkdb_version"`"
        cd drivers
        
        if [ $# == 0 ]; then
            usage
        fi

        case "$1" in
            javascript) bump_javascript "$rethinkdb_top_version" ;;
            python)     bump_python "$rethinkdb_top_version" ;;
            ruby)       bump_ruby "$rethinkdb_top_version" ;;
            minor)      bump_minor ;;
            major)      bump_major ;;
            revision)   bump_revision ;;
            *)          usage ;;
        esac
}

# top 1.2.3 -> 1.2
top () {
    echo -n "${1%.*}"
}

# top 1.2.3 -> 3
revision () {
    echo -n "${1#*.*.}"
}

bump_javascript () {
    current_version="$(node -e "p=$(cat javascript/package.json); console.log(p.version)")"
    new_version="`bump javascript "$current_version" "$1"`"
    node -e "p=`cat javascript/package.json`; p.version = '$new_version'; console.log(p)" > javascript/package.json
}

bump_python () {
    current_version="`perl -ne '/version="(.*?)"/ && print $1' python/setup.py`"
    new_version="`bump python "$current_version" "$1"`"
    perl -i -pe 's/version=".*?"/version="'"$new_version"'"/' python/setup.py
}

bump_ruby () {
    current_version="`perl -ne "/version.*?= '(.*?)'/ && print "'$'"1" ruby/rethinkdb.gemspec`"
    new_version="`bump python "$current_version" "$1"`"
    perl -i -pe 's/(version.*?= '"'"').*?('"'"')/$1 . "'"$new_version"'" . $2/e' ruby/rethinkdb.gemspec
}

# bump <driver name> <driver version> <rethinkdb top version>
bump () {
    echo Currrent $1 version: "'$2'" >&3
    current_top_version="`top "$2"`"
    current_revision="`revision "$2"`"
    if [ "$current_top_version" == "$3" ]; then
        new_version="$current_top_version.`expr "$current_revision" + 1`"
    else
        new_version="$3.0"
    fi
    echo New $1 version: "'$new_version'" >&3
    echo -n "$new_version"
}

bump_major () {
    echo Current rethinkdb version: $rethinkdb_version
    new_version="`expr ${rethinkdb_version%%.*} + 1`.0.0"
    echo New rethinkdb version: $new_version
    bump_rethinkdb "$new_version" bump_drivers
}

bump_minor () {
    echo Current rethinkdb version: $rethinkdb_version
    major="${rethinkdb_top_version%.*}"
    minor="${rethinkdb_top_version#*.}"
    new_version="$major.`expr "$minor" + 1`.0"
    echo New rethinkdb version: $new_version
    bump_rethinkdb "$new_version" bump_drivers
}

bump_revision () {
    echo Current rethinkdb version: $rethinkdb_version
    revision="`revision "$rethinkdb_version"`"
    new_version="$rethinkdb_top_version.`expr "$revision" + 1`"
    echo New rethinkdb version: $new_version
    bump_rethinkdb "$new_version" do_not_bump_drivers
}

bump_rethinkdb () {
    if grep -q "$1" ../NOTES; then
        if grep -q "INSERT THE LIST OF CHANGES HERE" ../NOTES ||
           grep -q "RELEASE NAME" ../NOTES; then
            echo "[1mAction required: List the changes in the NOTES file and run $0[0m"
            echo "Edit the lines containing 'INSERT THE LIST OF CHANGES HERE'"
            echo "Add the correct version name instead of 'RELEASE NAME'"
            exit
        else
            echo NOTES file seems up to date
        fi
    else
        cat > ../NOTES.new <<EOF
# Release $1 (RELEASE NAME) #

## Changes ##

* >>> INSERT THE LIST OF CHANGES HERE

---

EOF
        cat ../NOTES >> ../NOTES.new
        mv -f ../NOTES.new ../NOTES
        echo "[1mAction required: List the changes in the NOTES file and run $0 again[0m"
        exit
    fi
    git add ../NOTES

    if [ "$2" == bump_drivers ]; then
        rethindb_top_version="`top "$1"`"
        bump_javascript "$rethindb_top_version"
        bump_python "$rethindb_top_version"
        bump_ruby "$rethindb_top_version"
        git add -u .
    fi

    git commit -m "Prepare for v$1 release"
    git tag -a -m "v$1 release" "v$1"

    echo "New version is tagged and commited."
    echo "You must manually run [1mgit push[0m to share this release"
}

main "$@" 3>&1