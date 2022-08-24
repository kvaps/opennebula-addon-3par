#!/bin/bash
for j in 0 1 2; do
for i in vmm datastore tm; do
  (set -x; kubectl cp $i opennebula-oned-$j:/var/lib/one/remotes/ -c oned)
done
done
