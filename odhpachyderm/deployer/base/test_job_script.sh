
# Logic description
# Check if parameter "storage_secret" is 'pachyderm-ceph-secret', then it executes: 
#  - Storage Setup Part
#  - Pachyderm Part
# However, the storage_secret was set different name, it execute only:
#  - Pachyderm part

isPodReady(){
  local pod_name=$1
  ready_pod=$(oc get pod $pod_name  --no-headers|awk '{print $2}' |cut -d/ -f1)
  desired_pod=$(oc get pod $pod_name  --no-headers|awk '{print $2}' |cut -d/ -f2)

  if [[ ${ready_pod} == ${desired_pod} ]]
  then 
	  echo "0" # READY
  else
    echo "1" # NOT READY
  fi
}


# Storage Setup Part
## Check if customer set a custom secret name
pachyderm-ceph-secret=pachyderm-ceph-secret
if [[ ${pachyderm-ceph-secret} == ${STORAGE_SECRET_NAME} ]]
then
  ## Ceph exist in the same namespace
  ceph_statefulset_name=$(oc get statefulset --no-headers -o=custom-columns=name:metadata.name)
  if [[ z ==  z${ceph_statefulset_name} ]] 
  then
    echo "Ceph is not created. Please add Ceph component into KfDef"
    exit 1
  fi
  
  ceph_pod_name=$(oc get pod -l app=ceph --no-headers -o=custom-columns=name:metadata.name)

  ## Wait for Ceph pod is Ready
  cephReady=1
  while [[ ${cephReady} != 0 ]]
  do
    echo ""
    echo "INFO: Ceph Nano is NOT Ready."

    sleep 1
    isPodReady ${ceph_pod_name}
    cephReady=$?

    oc get secret ceph-nano-credentials
    cephReady=$?    
  done

  echo ""
  echo "Ceph is ready"

  ## Create an object bucket "pachyderm-storage"
  export access_key=$(oc get secret ceph-nano-credentials -o jsonpath='{ .data.AWS_ACCESS_KEY_ID}'|base64 -d)
  export secret_key=$(oc get secret ceph-nano-credentials -o jsonpath='{ .data.AWS_SECRET_ACCESS_KEY}'|base64 -d)

  mkdir /tmp/s3
cat << EOF > /tmp/s3/createBucket.py
import boto.s3.connection

access_key = '${access_key}'
secret_key = '${secret_key}'
conn = boto.connect_s3(
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        host='127.0.0.1', port=8000,
        is_secure=False, calling_format=boto.s3.connection.OrdinaryCallingFormat(),
      )

bucket = conn.create_bucket('pachyderm-storage')
for bucket in conn.get_all_buckets():
    print "{name} {created}".format(
        name=bucket.name,
        created=bucket.creation_date,
    )    
EOF

  oc rsync /tmp/s3 ceph-nano-0:/home/
  oc exec ceph-nano-0 -c ceph-nano -- /usr/bin/yum install python-boto -y
  oc exec ceph-nano-0 -c ceph-nano -- /usr/bin/python /home/s3/createBucket.py
  sleep 3
                

  ## Create a secret "pachyderm-ceph-secret" for the bucket "pachderm-storage"
  endpoint=$(oc get svc ceph-nano-0 -o jsonpath='{ .spec.clusterIP }')

  oc create secret generic ${pachyderm_secret_name} \
  --from-literal=access-id=${access_key}  \
  --from-literal=access-secret=${secret_key} \
  --from-literal=custom-endpoint=http://${endpoint} \
  --from-literal=region=us-east-2 \
  --from-literal=bucket=pachyderm-storage
else 
  secreat_exist=$(oc get secret ${STORAGE_SECRET_NAME} --no-headers |wc -l)
  if [[ ${secret_exist} == 1 ]]
  then
    pachyderm_secret_name=${STORAGE_SECRET_NAME}
  else
    echo "Secret \"${STORAGE_SECRET_NAME}\" does not exist"
    echo "Please check the secret"
    exit 1
  fi
fi
# Pachyderm Part
## Create Pachyderm CR with the secret
echo "
kind: Pachyderm
apiVersion: aiml.pachyderm.com/v1beta1
metadata:
  name: pachyderm-ceph
spec:
  console:
    disable: true
  pachd:
    metrics:
      disable: false
    storage:
      amazon:
        credentialSecretName: ${pachyderm_secret_name}
      backend: AMAZON
"|oc apply -f -
echo "Pachyderm Deployer is successfully finished"





