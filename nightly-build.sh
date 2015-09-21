#!/bin/bash
set -e

# Do osm2pgsql nightly builds
# Author: Paul Norman <penorman@mac.com>
# Author: Robert Coup <robert@coup.net.nz>
# License: GPL-2+


# User variables
DEST="openstreetmap" # the launchpad account name to upload to, not your name
# Build signing info...
GPGKEY=15746D5C
DEBFULLNAME="Paul Norman (PPA signing key)"
FULLNAME="Paul Norman"
DEBEMAIL="penorman@mac.com"

BRANCH=master
RELEASE_VERSION="0.89.0-dev"
PACKAGE="osm2pgsql"
PPA="ppa:$DEST/osm2pgsql-dev"
DISTS="trusty"

# parse command line opts
OPT_DRYRUN=""
OPT_FORCE=""
OPT_CLEAN=""
OPT_BUILDREV="1"
BRANCHES_TO_BUILD="${!BRANCHES[@]}"
OPT_BUILDDISTS=""
while getopts "fncr:b:d:" OPT; do
    case $OPT in
        c)
           OPT_CLEAN="1"
           ;;
        n)
           OPT_DRYRUN="1"
           ;;
        f)
           OPT_FORCE="1"
           ;;
        b)
           # Jenkins does stupid things with quotes
           BRANCHES_TO_BUILD=$(echo $OPTARG | sed s/\"//g)
           ;;
        d)
           # Jenkins does stupid things with quotes
           OPT_BUILDDISTS=$(echo $OPTARG | sed s/\"//g)
           ;;
        r)
           OPT_BUILDREV="$OPTARG"
           ;;
        \?)
            echo "Usage: $0 [-f] [-n] [-c] [-b N]" >&2
            echo "  -n         Skip the PPA upload & saving changelog." >&2
            echo "  -f         Force a build, even if the script does not want to. You may " >&2
            echo "             need to clean up debs/etc first." >&2
            echo "  -c         Delete archived builds. Leaves changelogs alone." >&2
            echo "  -r N       Use N as the Debian build revision (default: 1)" >&2
            echo "  -b BRANCH  Just deal with this branch. (default: ${!BRANCHES[@]})" >&2
            # this is kinda dangerous, it stuffs up prev.rev
            #echo "  -d DIST   Just deal with this dist. (default: $DISTS)" >&2
            exit 2
            ;;
    esac
done

if [ ! -z $OPT_CLEAN ]; then
    # delete old archives
    PACKAGE="${PACKAGES[$BRANCH]}"
    echo -e "\n*** Branch $BRANCH (${PACKAGE})"
    echo "rm -rvI \"${BRANCH}\"/${PACKAGE}-*"
    rm -rvI "${BRANCH}"/${PACKAGE}-*
    exit 0
fi

DATE=$(date +%Y%m%d)
DATE_REPR=$(date -R)

# update the git data - do this once for all builds
pushd git
git fetch origin
popd

echo -e "\n*** Branch $BRANCH (${PACKAGE})"

pushd git
git checkout -q "origin/$BRANCH"
REV="$(git log -1 --pretty=format:%h)"
if [ ! -f "../${BRANCH}/prev.rev" ]; then
   echo > "../${BRANCH}/prev.rev";
fi
REV_PREV="$(cat ../${BRANCH}/prev.rev)"
echo "Previous revision was ${REV_PREV}"

echo "placing GIT_REVISION file for launchpad build"
git rev-list --max-count=1 HEAD > GIT_REVISION

# Shall we build or not ? 
if [ "$REV" == "${REV_PREV}" ]; then
    echo "No need to build!"
    if [ -z "$OPT_FORCE" ]; then
        popd
        continue
    fi
    echo "> ignoring..."
    CHANGELOG="  * : No changes"
else
    # convert git changelog into deb changelog.
    # strip duplicate blank lines too
    REV_PREV2=$(echo "$REV_PREV" | awk '{print $1+1}')
    CHANGELOG="$(git log $REV_PREV..$REV --pretty=format:'[ %an ]%n>%s' | ../gitcl2deb.sh)"
fi

BUILD_VERSION="${RELEASE_VERSION}+dev${DATE}.git.${REV}"

SOURCE="${PACKAGE}-${BUILD_VERSION}"
ORIG_TGZ="${PACKAGE}-${BUILD_VERSION}.orig.tar.gz"
echo "Building orig.tar.gz ..."
if [ ! -f "../${BRANCH}/${ORIG_TGZ}" ]; then
    git archive --format=tar "--prefix=${SOURCE}/" "${REV}" | gzip >"../${BRANCH}/${ORIG_TGZ}"
else
    echo "> already exists - skipping ..."
fi
popd

pushd $BRANCH
echo "Build Version ${BUILD_VERSION}"
DISTS_TO_BUILD=${DISTS[$BRANCH]}
echo "Dists to build for $BRANCH: $DISTS_TO_BUILD"
if [ ! -z "$OPT_BUILDDISTS" ]; then
    DISTS_TO_BUILD=$OPT_BUILDDISTS
    echo "> Overriding to dists: $OPT_BUILDDISTS"
fi

for DIST in $DISTS_TO_BUILD; do
    echo "Building $DIST ..."
    DIST_VERSION="${BUILD_VERSION}-${OPT_BUILDREV}~${DIST}1"
    echo "Dist-specific Build Version ${DIST_VERSION}"

    # start with a clean export
    tar xzf $ORIG_TGZ
    # add the debian/ directory
    rsync -a debian $SOURCE

    # update the changelog
    # urgency=medium gets us up the Launchpad queue a bit...
    cat >$SOURCE/debian/changelog <<EOF
${PACKAGE} (${DIST_VERSION}) ${DIST}; urgency=medium
${CHANGELOG}
 -- ${FULLNAME} <${DEBEMAIL}>  ${DATE_REPR}
EOF
    # append previous changelog
    if [ -f $DIST.changelog ]; then
        cat $DIST.changelog >>$SOURCE/debian/changelog
    fi

    pushd $SOURCE
    echo "Actual debuild time..."
    # build & sign the source package
    debuild -S -k${GPGKEY}

    # woohoo, success!
    popd

    # send to ppa
    echo "Sending to PPA..."
    if [ -z "$OPT_DRYRUN" ]; then
        dput -f "$PPA" "${PACKAGE}-${DIST_VERSION}_source.changes"

        # save changelog for next time
        cp $SOURCE/debian/changelog $DIST.changelog
    else
        echo "> skipping..."
    fi
done

# save the revision for next time
# FIXME: what if one dist build succeeds and another fails?
# or we're using -d option?
if [ -z "$OPT_DRYRUN" ]; then
    echo "$REV" > prev.rev
fi
popd

