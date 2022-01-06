# Logic description
# Check if parameter "storage_secret" is 'pachyderm-ceph-secret', then it executes: 
#  - Storage Setup Part
#  - Pachyderm Part
# However, the storage_secret was set different name, it execute only:
#  - Pachyderm part


# Storage Setup Part
## Ceph exist in the same namespace
ceph_exist=$(oc get statefulset ceph-0 --header|wc -l)
if [[ ceph_exist ==  0 ]] 
then
  echo "Ceph is not created. Please add Ceph component into KfDef"
  exit 1
fi
 
ceph_ready = 1
## Wait for Ceph pod is Ready
while [ ceph_ready ]
do
  ceph_readoc get pod -l app=ceph_ready 
done



## Create an object bucket "pachyderm-storage"


# Pachyderm Part
## Create a secret "pachyderm-ceph-secret" for the bucket "pachderm-storage"

## Create Pachyderm CR with the secret