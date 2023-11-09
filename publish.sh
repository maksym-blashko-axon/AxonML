#!/bin/bash

#
# Usage:
#     publish.sh [POD Repo name] [framework name]
#
POD_REPO=maksym-blashko-axon
FRAMEWORK_NAME=AxonML

if [ $# == 2 ]; then
    POD_REPO=$1
    FRAMEWORK_NAME=$2
fi

pod repo list | grep ^${POD_REPO}

if [ $? -ne 0 ]; then
    echo "===================================================================================="
    echo "POD adding repository ${POD_REPO} git@github.com:${POD_REPO}/AxonML.git"
    echo "===================================================================================="

#    pod repo add ${POD_REPO} https://github.com/maksym-blashko-axon/AxonML.git
    pod repo add ${POD_REPO} git@github.com:maksym-blashko-axon/AxonML.git

    if [ $? -ne 0 ]; then
        echo "WARN: couldn't add pod repo ${POD_REPO}"
        exit 1
    fi
fi

echo "===================================================================================="
echo "Pushing spec ${FRAMEWORK_NAME}.podspec to ${POD_REPO}"
echo "===================================================================================="
pod repo push ${POD_REPO} ${FRAMEWORK_NAME}.podspec --verbose --skip-tests --skip-import-validation

if [ $? -ne 0 ]; then
    echo "FATAL: failed pushing podspec"
    exit 2
fi

echo "Success!"
