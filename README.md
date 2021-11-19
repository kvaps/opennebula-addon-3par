# HPE 3PAR Storage Driver

## Description

The 3PAR datastore driver enables OpenNebula to use a [HPE 3PAR](https://www.hpe.com/us/en/storage/3par.html) storage system for storing disk images.

## Development

To contribute bug patches or new features, you can use the GitLab Merge Request model. It is assumed that code and documentation are contributed under the Apache License 2.0.

More info:

* Issues Tracking: GitHub issues (https://github.com/wedos/opennebula-addon-3par/issues)

## Authors

* Original design and implementation: Kristian Feldsam (feldsam@feldhost.net)
* Rework and new versions adaptation: Andrei Kvapil (kvapss@gmail.com)
* Debian adaptation and tests: Egor Pronin (pronin.egor@gmail.com)

## Support

[WEDOS Cloud](https://www.wedos.com/cloud) offers design, implementation, operation and management of a cloud solution based on OpenNebula.

## Compatibility

This add-on is developed and tested with:
- OpenNebula 5.12 and 3PAR OS 3.3.1 (MU5)+P126,P132,P135,P140,P141,P146,P150,P151,P155

## Requirements

### OpenNebula Front-end

* Working OpenNebula CLI interface with `oneadmin` account authorized to OpenNebula's core with UID=0
* Password-less SSH access from the front-end `oneadmin` user to the `node` instances.
* 3PAR python package `python-3parclient` installed, WSAPI username, password and access to the 3PAR API network

#### Ubuntu

```bash
apt-get install python python3-pip
pip3 install python-3parclient xmltodict
```

#### Debian

```bash
apt-get install python python-dev python3-dev python3-pip python3-setuptools build-essential libssl-dev libffi-dev
pip3 install --upgrade pip
pip3 install python-3parclient xmltodict
```
### OpenNebula Node (or Bridge Node)

* sg3_utils package installed
* `/etc/sudoers.d/opennebula` - add `ONE_3PAR` cmd alias

```
cat > /etc/sudoers.d/opennebula-3par <<\EOT
Cmnd_Alias ONE_3PAR = /sbin/multipath, /usr/sbin/multipathd, /sbin/dmsetup, /usr/sbin/blockdev, /usr/bin/tee /sys/block/*/device/delete, /usr/bin/rescan-scsi-bus.sh, /usr/sbin/iscsiadm, /usr/bin/cat /etc/iscsi/initiatorname.iscsi
oneadmin ALL=(ALL) NOPASSWD: ONE_3PAR
EOT
```

#### Ubuntu
```bash
apt-get install open-iscsi multipath-tools
```

#### Debian
```bash
apt-get install open-iscsi multipath-tools lsscsi netcat-openbsd
```

## Features
Support standard OpenNebula datastore operations:

* datastore configuration via CLI
* all Datastore MAD(DATASTORE_MAD) and Transfer Manager MAD(TM_MAD) functionality
* SYSTEM datastore
* TRIM/discard in the VM when virtio-scsi driver is in use (require `DEV_PREFIX=sd` and `DISCARD=unmap`)
* disk images can be full provisioned, thin provisioned, thin deduplicated, thin compressed or thin deduplicated and compressed RAW block devices
* support different 3PAR CPGs as separate datastores
* support for 3PAR Priority Optimization Policy (QoS)
* live VM snapshots
* live VM migrations
* Volatile disks support (need patched KVM driver `attach_disk` script)
* Configuration of API endpoint and auth in datastore template
* Automatic hosts registration and configuration
* Option to reduce iSCSI endpoints usage
* Suspend/unsuspend to 3par volumes
* Multiple 3PARs systems support

## Limitations

1. FibreChannel is not currently supported.
1. Tested only with KVM hypervisor
1. When SYSTEM datastore is in use the reported free/used/total space is the space on 3PAR CPG. (On the host filesystem there are mostly symlinks and small files that do not require much disk space)
1. Tested/confirmed working on Ubuntu 20.04 (Frontend) and Ubuntu 20.04 (Nodes) / Debian 10 (Frontend and Nodes).

## ToDo

1. QOS Priority per VM

## Installation

The installation instructions are for OpenNebula 5.6+.

### Get the addon from github
```bash
cd ~
git clone https://github.com/kvaps/opennebula-addon-3par.git
```

### Installation

The following commands are related to latest OpenNebula version.

#### oned related pieces

* Copy 3PAR's DATASTORE_MAD driver files
```bash
cp -a ~/opennebula-addon-3par/datastore/3par /var/lib/one/remotes/datastore/

# copy config
cp -a ~/opennebula-addon-3par/etc/datastore/3par /var/lib/one/remotes/etc/datastore/

# fix ownership
chown -R oneadmin.oneadmin /var/lib/one/remotes/datastore/3par /var/lib/one/remotes/etc/datastore/3par

```

* Copy 3PAR's TM_MAD driver files
```bash
cp -a ~/opennebula-addon-3par/tm/3par /var/lib/one/remotes/tm/

# fix ownership
chown -R oneadmin.oneadmin /var/lib/one/remotes/tm/3par
```

* Copy 3PAR's VM_MAD driver files
```bash
cp -a ~/opennebula-addon-3par/vmm/kvm /var/lib/one/remotes/vmm/

# fix ownership
chown -R oneadmin.oneadmin /var/lib/one/remotes/vmm/kvm
```

### Addon configuration
The global configuration of one-addon-3par is in `/var/lib/one/remotes/etc/datastore/3par/3par.conf` file.


* Edit `/etc/one/oned.conf` and add `3par` to the `TM_MAD` arguments
```
TM_MAD = [
    executable = "one_tm",
    arguments = "-t 15 -d dummy,lvm,shared,fs_lvm,qcow2,ssh,vmfs,ceph,dev,3par"
]
```

* Edit `/etc/one/oned.conf` and add `3par` to the `DATASTORE_MAD` arguments

```
DATASTORE_MAD = [
    executable = "one_datastore",
    arguments  = "-t 15 -d dummy,fs,vmfs,lvm,ceph,dev,3par  -s shared,ssh,ceph,fs_lvm,qcow2,3par"
]
```

* Edit `/etc/one/oned.conf` and append `TM_MAD_CONF` definition for 3par
```
TM_MAD_CONF = [
  NAME = "3par", LN_TARGET = "NONE", CLONE_TARGET = "SYSTEM", SHARED = "yes", DRIVER = "raw", ALLOW_ORPHANS="yes"
]
```

* Edit `/etc/one/oned.conf` and append DS_MAD_CONF definition for 3par
```
DS_MAD_CONF = [
    NAME = "3par",
    REQUIRED_ATTRS = "CPG,BRIDGE_LIST",
    PERSISTENT_ONLY = "NO",
    MARKETPLACE_ACTIONS = ""
]
```

* Edit `/etc/one/oned.conf` and update VM_MAD arguments for 3par

```
VM_MAD = [
      ARGUMENTS = "-t 15 -r 0 kvm -l save=save-3par,restore=restore-3par,snapshotcreate=snapshot_create-3par,snapshotdelete=snapshot_delete-3par,snapshotrevert=snapshot_revert-3par",
      ...
```

* Enable live disk snapshots support for 3PAR by adding `kvm-3par` to `LIVE_DISK_SNAPSHOTS` variable in `/etc/one/vmm_exec/vmm_execrc`
```
LIVE_DISK_SNAPSHOTS="kvm-qcow2 kvm-ceph kvm-3par"
```

### Post-install
* Restart `opennebula` service
```bash
systemctl restart opennebula
```
* As oneadmin user (re)sync the remote scripts
```bash
su - oneadmin -c 'onehost sync --force'
```

### Volatile disks support info

To make volatile disks working, we need to patch vmm driver action `attach_disk`. Patched file is available in `vmm/kvm`
directory and have to be installed to `/var/lib/one/remotes/vmm/kvm/`.

### Configuring the System Datastore

This addon enables full support of transfer manager (TM_MAD) backend of type 3par for the system datastore.  
The system datastore will hold only the symbolic links to the 3PAR block devices and context isos, so it will not take much space. See more details on the [Open Cloud Storage Setup](https://docs.opennebula.org/5.8/deployment/open_cloud_storage_setup/).

### Configuring the Datastore

Some configuration attributes must be set to enable a datastore as 3PAR enabled one:

* **DS_MAD**: [mandatory] The DS driver for the datastore. String, use value `3par`
* **TM_MAD**: [mandatory] Transfer driver for the datastore. String, use value `3par`
* **DISK_TYPE**: [mandatory for IMAGE datastores] Type for the VM disks using images from this datastore. String, use value `block`
* **CPG**: [mandatory] Name of Common Provisioning Group created on 3PAR. String
* **THIN**: Use thin volumes `tpvv` or no. By default enabled. `YES|NO`
* **DEDUP**: Use deduplicated thin volumes `tdvv` or no. By default disabled. `YES|NO`
* **COMPRESSION**: Use compressed thin volumes or no. By default disabled. `YES|NO`
* **NAMING_TYPE**: Part of volume name defining environment. By default `dev`. String (1)
* **BRIDGE_LIST**: Nodes to use for image datastore operations. String (2)
* **QOS_ENABLE**: Enable QoS. `YES|NO` (3)
* **QOS_PRIORITY**: QoS Priority. `HIGH|NORMAL|LOW` (4)
* **QOS_MAX\_IOPS**: QoS Max IOPS. Int (5)
* **QOS_MIN\_IOPS**: QoS Min IOPS. Int (6)
* **QOS_MAX\_BW**: QoS Man bandwidth in kB/s. Int (7)
* **QOS_MIN\_BW**: QoS Min bandwidth in kB/s. Int (8)
* **QOS_LATENCY**: QoS Latency goal in ms. Int (9)

1. Volume names are created according to best practices naming conventions.
   `<TYPE>` part - can be prd for production servers, dev for development servers, tst for test servers, etc.
   Volume name will be `<TYPE>.one.<IMAGE_ID>.vv` for ex. `dev.one.1.vv` or `tst.one.3.vv`
   
2. Quoted, space separated list of server hostnames which are Hosts on the 3PAR System.

3. QoS Rules - Applied per VM, so if VM have multiple disks, them QoS policy applies to all VM disks
   - minimum goals and maximum limits are shared.
   Persistent disks use `QOS_*` attributes from IMAGE datastore.
   Non-Persistent disks use `QOS_*` attributes from target SYSTEM datastore.

4. QoS Priority - Determines the sequence for throttling policies to meet latency goals.
   High priority should be used for critical applications, lower priority should be used for less critical applications.
   The priority will be ignored if the system does not have policies with a latency goal and minimum goal.

5. The maximum IOPS permitted for the virtual volumes associated with the policy.
   The IOPS maximum limit must be between 0 and 2 147 483 647 IO/s.

6. If IOPS fall below this minimum goal, then IOPS will not be throttled (reduced) for the virtual volumes
   associated with the policy. If a minimum goal is set for IOPS, then a maximum limit must also be set for IOPS.
   The minimum goal will be ignored if the system does not have policies with a latency goal set.
   The IOPS minimum goal must be between 0 and 2 147 483 647 IO/s.
   Zero means disabled.

7. The maximum bandwidth permitted for the virtual volumes associated with the policy. The maximum limit does not have
   dependencies on the other optimization settings.
   The bandwidth maximum limit must be between 0 and 9 007 199 254 740 991 KB/s.

8. If bandwidth falls below this minimum goal, then bandwidth will not be throttled (reduced) for the virtual volumes
   associated with the policy. If a minimum goal is set for bandwidth, then a maximum limit must also be set
   for bandwidth. The minimum goal will be ignored if the system does not have policies with a latency goal set.
   The bandwidth minimum goal must be between 0 and 9 007 199 254 740 991 KB/s.
   Zero means disabled.

9. Service time that the system will attempt to achieve for the virtual volumes associated with the policy.
   A latency goal requires the system to have other policies with a minimum goal specified so that the latency goal
   algorithm knows which policies to throttle. The sequence in which these will be throttled is set
   by priority (low priority is throttled first).
   The latency goal must be between 0,50 and 10 000,00 ms.
   Zero means disabled.

The following example illustrates the creation of a 3PAR datastore.
The datastore will use hosts `tst.lin.fedora1.host`, `tst.lin.fedora2.host` and `tst.lin.fedora3.host` for importing and creating images.

#### Image datastore through *onedatastore*

```bash
# create datastore configuration file
$ cat >/tmp/imageds.tmpl <<EOF
NAME = "3PAR IMAGE"
DS_MAD = "3par"
TM_MAD = "3par"
TYPE = "IMAGE_DS"
DISK_TYPE = "block"
CPG = "SSD_r6"
NAMING_TYPE = "tst"
BRIDGE_LIST = "tst.lin.fedora1.host tst.lin.fedora2.host tst.lin.fedora3.host"
QOS_ENABLE = "YES"
EOF

# Create datastore
$ onedatastore create /tmp/imageds.tmpl

# Verify datastore is created
$ onedatastore list

  ID NAME                SIZE AVAIL CLUSTER      IMAGES TYPE DS       TM
   0 system             98.3G 93%   -                 0 sys  -        ssh
   1 default            98.3G 93%   -                 0 img  fs       ssh
   2 files              98.3G 93%   -                 0 fil  fs       ssh
 100 3PAR IMAGE         4.5T  99%   -                 0 img  3par     3par
```

#### System datastore through *onedatastore*

```bash
# create datastore configuration file
$ cat >/tmp/ds.conf <<EOF
NAME = "3PAR SYSTEM"
TM_MAD = "3par"
TYPE = "SYSTEM_DS"
CPG = "SSD_r6"
NAMING_TYPE = "tst"
QOS_ENABLE = "YES"
EOF

# Create datastore
$ onedatastore create /tmp/ds.conf

# Verify datastore is created
$ onedatastore list

  ID NAME                SIZE AVAIL CLUSTER      IMAGES TYPE DS       TM
   0 system             98.3G 93%   -                 0 sys  -        shared
   1 default            98.3G 93%   -                 0 img  fs       shared
   2 files              98.3G 93%   -                 0 fil  fs       ssh
 100 3PAR IMAGE         4.5T  99%   -                 0 img  3par     3par
 101 3PAR SYSTEM        4.5T  99%   -                 0 sys  -        3par
 ```

## 3PAR best practices guide incl. naming conventions

Please follow the [best practices guide](https://h20195.www2.hpe.com/v2/GetPDF.aspx/4AA4-4524ENW.pdf).
