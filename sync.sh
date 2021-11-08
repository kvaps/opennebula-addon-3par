#!/bin/bash
(set -x; kubectl cp ./migrate-vm.sh opennebula-oned-0:/tmp/migrate-vm.sh -c oned)
for i in vmm datastore tm; do
  (set -x; kubectl cp $i opennebula-oned-0:/var/lib/one/remotes/ -c oned)
done
