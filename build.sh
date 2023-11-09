#!/bin/bash

set -e

WORK_DIR=`pwd`
FRAMEWORK_NAME=AxonML
RELEASE_DIR=$WORK_DIR/dist/Release
POD_NAME=${FRAMEWORK_NAME}.xcframework
PACKAGE_NAME=${POD_NAME}.zip
XCARHCIVE_NAME=${FRAMEWORK_NAME}.archives.zip
VERSION=1.0.0
BUILD_TYPE=${1:-debug}
export BUILD_FOR_SIMULATOR_ENABLED=${BUILD_FOR_SIMULATOR_ENABLED:-true}

# =================================================================
# Get version from current tag
# =================================================================
function get_version() {
    if [ ! -z "$BITRISE_GIT_TAG" ]; then
        VERSION=$BITRISE_GIT_TAG
    fi

    echo "Building version=${VERSION}"
}

function build_framework() {
    echo " ================================================================="
    echo "  Build and package framework"
    echo " ================================================================="

    rm -rf build
    #xcodegen generate

    ./build_framework.sh "$@"
    if [ $? -ne 0 ]; then
        echo "Build framework failed"
        return 1
    fi
}


# =================================================================
# Prepare items for deploying to Bitrise Apps & Artifacts
# =================================================================
function bitrise_deploy() {
    echo " ================================================================="
    echo "  Deploy artefacts"
    echo " ================================================================="

    if [ -z "${BITRISE_DEPLOY_DIR}" ]; then
        echo "Deploying dir not specified - skip"
        return 0
    fi

    ITEMS_TO_DEPLOY=( "$PACKAGE_NAME" )
    if [ 0 -ne $1 ]; then
        ITEMS_TO_DEPLOY[${#ITEMS_TO_DEPLOY[@]}]="$XCARHCIVE_NAME"
    fi

    mkdir -p "${BITRISE_DEPLOY_DIR}"
    for ITEM in "${ITEMS_TO_DEPLOY[@]}" ; do
        if [ -f "${RELEASE_DIR}/$ITEM" ]; then
            echo "Deploying '$ITEM'..."
            cp -f "${RELEASE_DIR}/$ITEM" "${BITRISE_DEPLOY_DIR}"/
            if [ 0 -ne $? ]; then
                echo '... failed - ignore this error'
            fi
        else
            echo "Item '$ITEM' does not exist - ski=p deploying it"
        fi
    done
}

# =================================================================
# Publish spec
# =================================================================
function publish_pod_spec() {
    echo " ================================================================="
    echo "  Publishing POD spec"
    echo " ================================================================="

    # backup current pod spec first
    POD_SPEC="${FRAMEWORK_NAME}.podspec"
    POD_SPEC_BACKUP="${FRAMEWORK_NAME}.podspec.backup"
    if [ -f "$POD_SPEC" ]; then
        cat "$POD_SPEC" > "$POD_SPEC_BACKUP"
    fi

    sed -e "s/#VERSION#/${VERSION}/g" ${FRAMEWORK_NAME}.podspec.template > "$POD_SPEC"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo "Creating podspec failed"
    else
        ./publish.sh
        RESULT=$?
    fi

    # try to restore original pod spec
    if [ -f "$POD_SPEC_BACKUP" ]; then
        cat "$POD_SPEC_BACKUP" > "$POD_SPEC"
        rm -f "$POD_SPEC_BACKUP"
    fi

    return $RESULT
}

# =================================================================
# Upload release to github
# =================================================================
function uploade_release() {
    echo " ================================================================="
    echo "  Uploading release to github"
    echo " ================================================================="

    ./upload_release.sh
}

# =================================================================
# Main
# =================================================================
get_version

case "$BUILD_TYPE" in
    'release')
        build_framework
        if [ $? -ne 0 ]; then exit 1; fi

        bitrise_deploy 1
        publish_pod_spec
        uploade_release
        ;;
    'run-tests')
        build_framework run-tests
        if [ 0 -ne $? ]; then exit 1; fi
        ;;
    *)
        build_framework
        if [ $? -ne 0 ]; then exit 1; fi

        uploade_release
        bitrise_deploy 0
        ;;
esac

echo "Complete"
