#!/bin/bash
for i in vmm datastore tm; do
  (set -x; kubectl cp $i opennebula-oned-0:/var/lib/one/remotes/ -c oned)
done
