#!/bin/bash

source $TEST_DIR/common

MY_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)

source ${MY_DIR}/../util
PACHYDERM_CR="${MY_DIR}/../resources/pachyderm/pachyderm-cr.yaml"
PACHYDERM_SECRET="${MY_DIR}/../resources/pachyderm/pachyderm-secret-create.sh"
PACHYDERM_RESOURCE_DIR="${MY_DIR}/../resources/pachyderm"


os::test::junit::declare_suite_start "$MY_SCRIPT"

function create_ceph_bucket() {
    header "Create a new Ceph bucket my-new-bucket"
    oc rsync ${PACHYDERM_RESOURCE_DIR} -n ${ODHPROJECT} ceph-nano-0:/tmp
    oc exec pod/ceph-nano-0 -n ${ODHPROJECT} -- /bin/bash -c /tmp/pachyderm/ceph-bucket-create.sh
}

function create_pachyderm_secret() {
    header "Create a Secret for Pachyderm"
    export id=$(oc get secret ceph-nano-credentials -n ${ODHPROJECT} -o jsonpath='{ .data.AWS_ACCESS_KEY_ID}'|base64 -d)
    export secret=$(oc get secret ceph-nano-credentials -n ${ODHPROJECT} -o jsonpath='{ .data.AWS_SECRET_ACCESS_KEY}'|base64 -d)
    export endpoint=$(oc get svc ceph-nano-0 -n ${ODHPROJECT} -o jsonpath='{ .spec.clusterIP }' )

    oc delete secret pachyderm-ceph-secret --ignore-not-found

    oc create secret generic pachyderm-ceph-secret \
    --from-literal=access-id=${id}  \
    --from-literal=access-secret=${secret} \
    --from-literal=custom-endpoint=http://${endpoint} \
    --from-literal=region=us-east-2 \
    --from-literal=bucket=my-new-bucket

    os::cmd::try_until_text "oc get secret pachyderm-ceph-secret -n ${ODHPROJECT}" "pachyderm-ceph-secret" $odhdefaulttimeout $odhdefaultinterval
}

function create_pachyderm_cr() {
    header "Create a Pachyderm CR"
    oc apply -f ${PACHYDERM_CR} -n ${ODHPROJECT}
    os::cmd::try_until_text "oc get pachyderm pachyderm-ceph -n ${ODHPROJECT}" "pachyderm-ceph" $odhdefaulttimeout $odhdefaultinterval
}

function test_pachyderm() {
    header "Setup Pachyderm"
    os::cmd::expect_success "oc project ${ODHPROJECT}"
    
    os::cmd::try_until_text "oc get pod/ceph-nano-0 -n ${ODHPROJECT} |grep Running |wc -l" "1"

    create_ceph_bucket
	create_pachyderm_secret
	create_pachyderm_cr

    header "Verify Pachyderm"
    os::cmd::try_until_text "oc get deployment pachd -n ${ODHPROJECT}" "pachd" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get deployment pg-bouncer -n ${ODHPROJECT}" "pg-bouncer" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get statefulset etcd -n ${ODHPROJECT}" "etcd" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get statefulset postgres -n ${ODHPROJECT}" "postgres" $odhdefaulttimeout $odhdefaultinterval
    
    os::cmd::try_until_not_text "oc get pod -l app=pachd --field-selector='status.phase=Running' -n ${ODHPROJECT}" "No resources found"
    runningpods=($(oc get pods -l suite=pachyderm --field-selector="status.phase=Running" -o jsonpath="{$.items[*].metadata.name}" -n ${ODHPROJECT}))
    os::cmd::expect_success_and_text "echo ${#runningpods[@]}" "3"
}

test_pachyderm

os::test::junit::declare_suite_end
