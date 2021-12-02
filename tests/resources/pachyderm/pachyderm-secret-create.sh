export id=$(oc get secret ceph-nano-credentials -o jsonpath='{ .data.AWS_ACCESS_KEY_ID}'|base64 -d)
export secret=$(oc get secret ceph-nano-credentials -o jsonpath='{ .data.AWS_SECRET_ACCESS_KEY}'|base64 -d)
export endpoint=$(oc get svc ceph-nano-0 -o jsonpath='{ .spec.clusterIP }' )

oc delete secret pachyderm-ceph-secret --ignore-not-found

oc create secret generic pachyderm-ceph-secret \
--from-literal=access-id=${id}  \
--from-literal=access-secret=${secret} \
--from-literal=custom-endpoint=http://${endpoint} \
--from-literal=region=us-east-2 \
--from-literal=bucket=my-new-bucket
