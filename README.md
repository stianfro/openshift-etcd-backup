# OpenShift etcd backup CronJob

Openshift 4 backup
The Openshift 4 backup generates 2 different files with the date when it was performed.

- snapshot_2021-03-17_153108.db
- static_kuberesources_2021-03-15_153108.tar.gz

The .db file is a snapshot of the etcd and the .tar.gz contains the static pods of the control plane (etcd, api server, controller manager and scheduler) with their respective certificates and private keys. The backup that is made in a master contains the information of all masters, so it is only necessary to make it in a single master.



## Installation

Fist, create a namespace:
```
# oc new-project etcd-backup
```

Since the container needs to be privileged, add the reqired RBAC rules:
```
oc create -f backup-rbac.yaml
```

Then create a configmap with the backup-script:
```
# oc create configmap backup-script --from-file=backup.sh
```

Then adjust storage to your needs in `backup-storage.yaml` and deploy it. The example uses NFS but you can use any storage class you want.
```
# oc create -f backup-storage.yaml
```

Configure the backup-script (for now only retention in days can be configured in the)
```
oc create -f backup-config.yaml
```

Then deploy, and configure the cronjob
```
# find image hash
toolsImage=$(oc adm release info --image-for=tools)

# If you run in a restricted network, you need to add registry-config:
toolsImage=$(oc adm release info --image-for=tools --registry-config=./pull-secret.json)

# deploy the cronjob
oc create -f backup-cronjob.yaml

# adjust the tools image
oc patch cronjob/etcd-backup -p "{\"spec\":{\"jobTemplate\":{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"image\":\"${toolsImage}\",\"name\":\"backup-etcd\"}]}}}}}}'"
```

## Testing

To test the backup, you can run a job and verify its logs
```
oc create job --from=cronjob/etcd-backup etcd-manual-backup-001
oc logs -l job-name=etcd-manual-backup-001
```
Then check on your Storage, if the files are there as excepted.

## Change configuration

Configuration can be changed in configmap `backup-config`:

```
oc edit -n etcd-backup cm/backup-config
```

The following options are used:
* `backup.keepdays`: Days to keep the backup. Please note, that the number does not get validated.

Changing the schedule be done in the CronJob directly, with `spec.schedule`:
```
oc edit -n etcd-backup cronjob/etcd-backup
```
Default is `0 0 * * *` which means the cronjob runs one time a day at midnight.


## Update

After updating the cluster, it makes sense to update the image as well. To do this, execute the following:
```
# switch to project
oc project etcd-backup

# find image hash
toolsImage=$(oc adm release info --image-for=tools)

# If you run in a restricted network, you need to add registry-config:
toolsImage=$(oc adm release info --image-for=tools --registry-config=./pull-secret.json)

# adjust the tools image
oc patch cronjob/etcd-backup -p "{\"spec\":{\"jobTemplate\":{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"image\":\"${toolsImage}\",\"name\":\"backup-etcd\"}]}}}}}}'"
```


# References
* https://docs.openshift.com/container-platform/4.7/backup_and_restore/backing-up-etcd.html
