VMID=$1
NEW_DSID=204

if [ -z "$VMID" ]; then
    echo "usage: $0 <VMID>"
    exit 1
fi


XPATH="/var/lib/one/remotes/datastore/xpath.rb --stdin"

unset i k XPATH_ELEMENTS

while IFS= read -r -d '' element; do
    XPATH_ELEMENTS[i++]="$element"
done < <(onevm show $VMID -x | $XPATH \
    /VM/STATE \
    /VM/LCM_STATE \
    /VM/HISTORY_RECORDS/HISTORY[last\(\)]/SEQ \
    /VM/HISTORY_RECORDS/HISTORY[last\(\)]/HOSTNAME)

STATE=${XPATH_ELEMENTS[k++]}
LCM_STATE=${XPATH_ELEMENTS[k++]}
SEQ=${XPATH_ELEMENTS[k++]}
HOST=${XPATH_ELEMENTS[k++]}

if [ "$STATE" = 3 ] && [ "$LCM_STATE" = 3 ]; then
    onedb change-history --id "$VMID" --seq "$SEQ" HISTORY/TM_MAD 3par
    onevm migrate "$VMID" "$HOST" "$NEW_DSID"
elif [ "$STATE" = 3 ] && [ "$LCM_STATE" = 38 ]; then
    onevm recover --retry "$VMID"
else
    echo "STATE=$STATE, LCM_STATE=$LCM_STATE is not implemented yet!"
    exit 1
fi

echo -n "Migrating."
while STATE=$(onevm list -fID=$VMID -lSTAT --no-header) && [ "$STATE" = migr ]; do
  echo -n '.'
  sleep 5
done
echo
echo "Done, state: $STATE"
