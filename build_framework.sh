#!/bin/bash
#
#  build_framework.sh
#  AxonSDK
#

set -e

BUILD_TYPE=Release
BUILD_CONFIG=BuildRelease

FRAMEWORK_NAME=AxonML
FRAMEWORK_FULL_NAME=$FRAMEWORK_NAME.xcframework

POD_NAME=$FRAMEWORK_FULL_NAME
FW_DIST_DIR=`pwd`/dist/$BUILD_TYPE/
PACKAGE_NAME=${POD_NAME}.zip
ARHIVE_PACK_NAME=${FRAMEWORK_NAME}.archives.zip

if [ -n "${BITRISE_CONFIGURATION}" ]; then
    BUILD_CONFIG="${BITRISE_CONFIGURATION}"
fi

TESTS_DESTINATION='platform=iOS Simulator,name=iPhone 11,OS=14.5'
if [ -n "${BITRISE_TESTS_DESTINATION}" ]; then
    TESTS_DESTINATION="${BITRISE_TESTS_DESTINATION}"
fi

#
# Build framework
#

XC_BUILD_ROOT="build/${BUILD_CONFIG}"
XC_BUILD_ARCHIVES_ROOT="${XC_BUILD_ROOT}/archive"
XC_BUILD_CONFIG_MAIN=('-workspace' "${FRAMEWORK_NAME}.xcworkspace" '-scheme' "${FRAMEWORK_NAME}" '-derivedDataPath' "${XC_BUILD_ROOT}/build")
XC_BUILD_CONFIG_TESTS=('-workspace' "${FRAMEWORK_NAME}.xcworkspace" '-scheme' "${FRAMEWORK_NAME}Tests" '-destination' "${TESTS_DESTINATION}")
XC_CUSTOM_CONFIG=('BUILD_LIBRARY_FOR_DISTRIBUTION=YES\SKIP_INSTALL=NO')

clean() {
    # remove build dir to ensure a clean build
    echo "-----------------------------------------------------------------"
    echo " Cleaning ..."
    echo "-----------------------------------------------------------------"
    xcodebuild "${XC_BUILD_CONFIG_MAIN[@]}" clean
    
    return 0
}

archive() {
    echo "-----------------------------------------------------------------"
    echo " Archiving $1 (Configuration = ${BUILD_CONFIG}) ..."
    echo "-----------------------------------------------------------------"

    local BUILD_SDK="$1"
    shift
    
    ARCHIVE_BUILD_DIR="${XC_BUILD_ARCHIVES_ROOT}/${BUILD_SDK}/${FRAMEWORK_NAME}.xcarchive"
    xcodebuild \
        "${XC_BUILD_CONFIG_MAIN[@]}" \
        -configuration "${BUILD_CONFIG}" \
        -sdk "$BUILD_SDK" \
        -archivePath "$ARCHIVE_BUILD_DIR" \
        "$@" "${XC_CUSTOM_CONFIG[@]}" "${VERSION_ARGS[@]}" archive

    if [ 0 -ne $? ]; then return 1; fi
    
    echo "$ARCHIVE_BUILD_DIR"
    return 0
}

lint() {
    echo "-----------------------------------------------------------------"
    echo " Linting ..."
    echo "-----------------------------------------------------------------"
    pushd axonsdk
    swiftlint autocorrect
    ret=../Pods/SwiftLint/swiftlint
    popd
    return ret
}

prepare() {
    echo " Installing PODs"
    pod install
    if [ $? -ne 0 ]; then
        echo "Installing PODs failed"
        return 1
    fi
}

compile() {
    echo "-----------------------------------------------------------------"
    echo " Compiling ..."
    echo "-----------------------------------------------------------------"

    prepare
    if [ $? -ne 0 ]; then return 1; fi

    local VERSION_ARGS=( )
    if [ -n "${BITRISE_GIT_TAG}" ]; then
        BUILD_NUM=`echo "${BITRISE_GIT_TAG}" | awk '{num = split($0, vers, "."); if (4 > num || "" == vers[4]) print "1";  else  print vers[4] + 1}'`
        VERSION_STR=`echo "${BITRISE_GIT_TAG}" | awk '{num = split($0, vers, "."); if (3 < num) num=3; j=vers[1]; for (i=2;i<=num;i++) j=j "." vers[i]; print j}'`
        VERSION_ARGS=("MARKETING_VERSION=$VERSION_STR" "CURRENT_PROJECT_VERSION=$BUILD_NUM")
    fi

    local ARCHIVE_PATHS=( )
    
    echo " Build for device..."
    archive iphoneos
    ARCHIVE_PATHS[${#ARCHIVE_PATHS[@]}]=$ARCHIVE_BUILD_DIR
    if [ 0 -ne $? ]; then return 1; fi
    
    if [ "${BUILD_FOR_SIMULATOR_ENABLED}" = 'true' ]; then
        echo " Build for simulator..."
        archive iphonesimulator -destination 'generic/platform=iOS Simulator'
        ARCHIVE_PATHS[${#ARCHIVE_PATHS[@]}]=$ARCHIVE_BUILD_DIR
    fi
    
    FRAMEWORK_BUILD_DIR="build/Products/${BUILD_CONFIG}"
    
    echo " Make xcframework..."
    rm -rf "$FRAMEWORK_BUILD_DIR/$FRAMEWORK_FULL_NAME" 2>/dev/null
    
    local XCFWK_ARGS=( )
    for ARCH_PATH in "${ARCHIVE_PATHS[@]}"; do
        XCFWK_ARGS[${#XCFWK_ARGS[@]}]='-framework'
        XCFWK_ARGS[${#XCFWK_ARGS[@]}]="$ARCH_PATH/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework"
    done

    xcodebuild -create-xcframework "${XCFWK_ARGS[@]}" -output "$FRAMEWORK_BUILD_DIR/$FRAMEWORK_FULL_NAME"
    if [ 0 -ne $? ]; then return 1; fi
}

run_tests() {
    echo "######################################################"
    echo " Testing ..."
    echo "######################################################"

    prepare
    if [ 0 -ne $? ]; then return 1; fi

    local BASE_ARGS=( -configuration "${BUILD_CONFIG}" -sdk 'iphonesimulator' 'ENABLE_TESTABILITY=YES' )

    xcodebuild "${XC_BUILD_CONFIG_TESTS[@]}" "${BASE_ARGS[@]}" 'build-for-testing' 1>&2
    if [ 0 -ne $? ]; then return 1; fi

    local TEST=`arch | grep 'arm'`
    if [ -n "$TEST" ]; then
        echo 'Force run under Rosetta because Apple Silicon platform is not supported to run tests...'
        arch -x86_64 xcodebuild "${XC_BUILD_CONFIG_TESTS[@]}" "${BASE_ARGS[@]}" 'test' 1>&2
    else
        xcodebuild "${XC_BUILD_CONFIG_TESTS[@]}" "${BASE_ARGS[@]}" 'test' 1>&2
    fi
    if [ 0 -ne $? ]; then return 1; fi
}

#
# package framework
# Copy framework files to distribution directory ${FW_DIST_DIR}
#
package() {
    echo "-----------------------------------------------------------------"
    echo " Packaging framework AxonML ..."
    echo "-----------------------------------------------------------------"

    # remove distribution dir if exist
    if [ -d "$FW_DIST_DIR" ]; then
        echo "$FW_DIST_DIR exists, removing"
        rm -rf "$FW_DIST_DIR"
    fi

    mkdir -p "$FW_DIST_DIR"

    echo "copying $FRAMEWORK_FULL_NAME to $FW_DIST_DIR"
    cp -a "$FRAMEWORK_BUILD_DIR/$FRAMEWORK_FULL_NAME" "$FW_DIST_DIR"/
    if [ $? -ne 0 ]; then return 3; fi
    
    echo "copying $XC_BUILD_ARCHIVES_ROOT to $FW_DIST_DIR"
    cp -a "$XC_BUILD_ARCHIVES_ROOT" "$FW_DIST_DIR"/
    if [ $? -ne 0 ]; then return 3; fi

    #
    # Packaging
    #
    echo "Packaging ${PACKAGE_NAME} ..."
    pushd $FW_DIST_DIR

    zip -qry "${PACKAGE_NAME}" "${FRAMEWORK_FULL_NAME}"

    local ARHIVE_DIR_NAME=$(basename "$XC_BUILD_ARCHIVES_ROOT")
    zip -qry "${ARHIVE_PACK_NAME}" "${ARHIVE_DIR_NAME}"

    popd
    
    return 0
}

case $1 in
    clean)
        clean
        ;;
    run-tests)
        run_tests
        ;;
    build|*)
        #clean
        compile
        package
        ;;
esac


echo "AxonML xcframework is created!"
