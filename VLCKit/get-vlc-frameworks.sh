#!/bin/sh
# View latest releases on https://download.videolan.org/pub/cocoapods/prod/
# or list them
# curl "https://download.videolan.org/pub/cocoapods/prod/" | grep "3.5.1"

mkdir -p "VLCKit"
cd VLCKit

IOS_VERSION="3.7.2-3e42ae47-79128878"
TV_VERSION="3.7.2-3e42ae47-79128878"
MAC_VERSION="3.7.2-3e42ae47-79128878"

TV_URL="https://download.videolan.org/pub/cocoapods/prod/TVVLCKit-${TV_VERSION}.tar.xz"
iOS_URL="https://download.videolan.org/pub/cocoapods/prod/MobileVLCKit-${IOS_VERSION}.tar.xz"
MAC_URL="https://download.videolan.org/pub/cocoapods/prod/VLCKit-${MAC_VERSION}.tar.xz"


if [ "$1" == "tv" ] ; then
    echo "${TV_VERSION}" > Manifest.lock
    diff "tv-version.lock" "Manifest.lock" > /dev/null
    if [ $? == 0 ] ; then
        echo "SUCCESS TVVLCKit"
        exit 0
    fi
    echo "Dowloading - TVVLCKit-${TV_VERSION}"
    rm -rf "TVVLCKit-binary"
    curl -s "${TV_URL}" | tar -xz -
    echo "${TV_VERSION}" > tv-version.lock
    echo "SUCCESS"
elif [ "$1" == "ios" ] ; then
    echo "${IOS_VERSION}" > Manifest.lock
    diff "ios-version.lock" "Manifest.lock" > /dev/null
    if [ $? == 0 ] ; then
        echo "SUCCESS MobileVLCKit"
        exit 0
    fi
    echo "Dowloading - MobileVLCKit-${IOS_VERSION}"
    rm -rf "MobileVLCKit-binary"
    curl -s "${iOS_URL}" | tar -xz -
    echo "${IOS_VERSION}" > ios-version.lock
    echo "SUCCESS"
elif [ "$1" == "mac" ] ; then
    echo "${MAC_VERSION}" > Manifest.lock
    diff "mac-version.lock" "Manifest.lock" > /dev/null
    if [ $? == 0 ] ; then
        echo "SUCCESS VLCKit"
        exit 0
    fi
    echo "Dowloading - VLCKit-${MAC_VERSION}"
    rm -rf "VLCKit - binary package"
    curl -s "${MAC_URL}" | tar -xz -
    echo "${MAC_VERSION}" > mac-version.lock
    echo "SUCCESS"
else
    echo "Missing argument: [tv, ios, mac]"
    echo "Example:"
    echo "$0 ios"
fi
