# Pachyderm

[Pachyderm](https://www.pachyderm.com/products/) is the data foundation for machine learning and offers three different products to fit all machine learning operationalization (MLOps) needs.

**Folders**
There is one main folder in the Pachyderm component

- cluster: contains the subscription for the Pachyderm operator

**Installation**
To install Pachyderm operator, you should add the following to the `kfctl` yaml file. The `pachyderm_version` is about pachyderm operator version and you can check it from [here](https://catalog.redhat.com/software/containers/pachyderm/pachyderm-operator/61823a50dd607bfc82e65e14)
~~~
  - kustomizeConfig:
      parameters:
        - name: namespace
          value: openshift-operators
        - name: pachyderm_version
          value: 0.0.7
      repoRef:
        name: manifests
        path: odhpachyderm/cluster
    name: pachyderm-operator
~~~
If you want to install Ceph with ODH, you can refer to [this doc](https://github.com/opendatahub-io/odh-manifests/tree/master/ceph)

## Pachyderm Cluster
### Deployment of Pachyderm cluster ###
To deploy Pachyderm cluster, you should setup a storage. There are several storage options please refer [the official documentation](https://docs.pachyderm.com/latest/deploy-manage/deploy/). However, Pachyderm Operator only support Amazon.

**Secret Example**

- *AWS S3*
  ~~~
  $ oc create secret generic pachyderm-aws-secret \
  --from-literal=access-id=XXX  \
  --from-literal=access-secret=XXX \
  --from-literal=region=us-east-2 \
  --from-literal=bucket=pachyderm 
  ~~~

- *Ceph*
  ~~~
  $ export ceph_ns=opendatahub
  
  $ export ceph_ip=$(oc get svc ceph-nano-0 -o jsonpath='{.spec.clustreIp}')

  $ oc create secret generic pachyderm-ceph-secret \
  --from-literal=access-id=XXX  \
  --from-literal=access-secret=XXX \
  --from-literal=custom-endpoint=${ceph_ip}
  --from-literal=region=us-east-2 \
  --from-literal=bucket=pachyderm 
  ~~~


### Create a Pachyderm CR
- *AWS*
  ~~~
  apiVersion: aiml.pachyderm.com/v1beta1
  kind: Pachyderm
  metadata:
    name: pachyderm-sample
  spec:
    console:
      disable: true
    pachd:
      metrics:
        disable: false
      storage:
        amazon:
          credentialSecretName: pachyderm-aws-secret
        backend: AMAZON
  ~~~

- *Ceph*
  ~~~
  apiVersion: aiml.pachyderm.com/v1beta1
  kind: Pachyderm
  metadata:
    name: pachyderm-sample
  spec:
    console:
      disable: true
    pachd:
      metrics:
        disable: false
      storage:
        amazon:
          credentialSecretName: pachyderm-ceph-secret
        backend: AMAZON
  ~~~


*Pachyderm Running Pods*
~~~
$ oc get pod 
etcd-0                          1/1     Running   0          12m
postgres-0                      1/1     Running   0          12m
pachd-874f5958c-7w98p           1/1     Running   0          11m
pg-bouncer-7587d49769-gwn8f     1/1     Running   0          11m
~~~

## Reference
- [How to deploy Ceph Nano on OpenShift?](https://github.com/Jooho/jhouse_openshift/blob/master/docs/ceph-nano/ceph-nano-installation-on-openshift.md)
