#!/bin/bash

source $TEST_DIR/common

MY_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)

source ${MY_DIR}/../util
PACHYDERM_CR="${MY_DIR}/../resources/pachyderm/pachyderm-cr.yaml"
PACHYDERM_SECRET="${MY_DIR}/../resources/pachyderm/pachyderm-secret-create.sh"
PACHYDERM_RESOURCE_DIR="${MY_DIR}/../resources/pachyderm"


os::test::junit::declare_suite_start "$MY_SCRIPT"

function create_ceph_bucket() {
    header "Create a nes Ceph bucket `my-new-bucket`"
    os::cmd::expect_success "oc rsync ${PACHYDERM_RESOURCE_DIR} ceph-nano-0:/tmp"
    os::cmd::expect_success "oc exec pod/ceph-nano-0 -- /bin/bash -c /tmp/pachyderm/ceph-bucket-create.sh"
}

function create_pachyderm_secret() {
    header "Create a Secret for Pachyderm"
    os::cmd::expect_success "/bin/bash -c ${PACHYDERM_SECRET}"
}

function create_pachyderm_cr() {
    header "Create a Pachyderm CR"
    os::cmd::expect_success "oc create -f ${PACHYDERM_CR}"
}

function test_pachyderm() {
    header "Setup Pachyderm"
    os::cmd::expect_success "oc project ${ODHPROJECT}"

    create_ceph_bucket
	create_pachyderm_secret
	create_pachyderm_cr

    header "Verify Pachyderm"
    os::cmd::try_until_text "oc get deployment pachd" "pachd" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get deployment pg-bouncer" "pg-bouncer" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get statefulset etcd" "etcd" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get statefulset postgres" "postgres" $odhdefaulttimeout $odhdefaultinterval

    runningpods=($(oc get pods -l suite=pachyderm --field-selector="status.phase=Running" -o jsonpath="{$.items[*].metadata.name}"))
    os::cmd::expect_success_and_text "echo ${#runningpods[@]}" "3"
}

test_pachyderm

os::test::junit::declare_suite_end
