#!/bin/bash

trap 'exit' INT TERM
trap 'kill 0' EXIT

while [[ $# -gt 0 ]]; do
    case $1 in
    -h|--help)
        echo "ON database renaming script for 3PAR VVs"
        echo "Options:"
        echo "    -n, --naming    3PAR naming type, e.g.: 'dev'"
        echo "    -r, --reverse   Rename from new scheme to the old one"
        echo "    -D, --database  ON database name"
        echo "    -d, --dry-run   Do not rename, only show differences"
        echo "    -o, --output    Directory for dry-run diff files. Defaults to '/var/tmp'"
        exit
        ;;
    -r|--reverse)
        REVERSE=1
        shift
        ;;
    -n|--naming)
        namingType=$2
        shift
        shift
        ;;
    -D|--database)
        DB=$2
        shift
        shift
        ;;
    -d|--dry-run)
        dryRun=1
        shift
        ;;
    -o|--output)
        outDir=$2
        shift
        shift
        ;;
    *)
        echo "Unknown argument $1 - skipping"
        shift
        ;;
    esac
done

if [[ -z $namingType ]]; then
    echo "Missing naming type"
    exit 1
fi;
outDir=${outDir:-"/var/tmp"}

if (( dryRun )); then
    echo "Dry run!"
    echo "Output directory: '$outDir'"
else
    echo "Live run!"
fi;
if (( REVERSE )); then
    echo "Reverse"
else
    echo "Normal"
fi;
echo "$namingType"
echo "Is everything correct? [y/n]"
read IN
if [[ $IN != "y" ]]; then
    exit 0
fi;

DB=${DB:-"opennebula"}
# DB access? rewriting VMs?
#DB_VMs=$(mysql $DB <<< "select oid from vm_pool order by oid desc;")
VMs=$(onevm list --no-pager --no-header | mawk '{print $1}')
lastVM=$(echo "$VMs" | sort -nr | head -n1)
images=$(oneimage list --no-pager --no-header | mawk '{print $1}')
declare -ag imageArray
imageArray=($images)

if (( REVERSE )); then
    #'/stg2\..*[0-9]:/ {s/stg2/stg2.one/; s/:/.vv:/}
    CMD="/usr/bin/sed -i '/$namingType\..*[0-9]:/ {s/$namingType/$namingType.one/; s/:/.vv:/}'"
else
    #'/stg2\.one\..*\.vv:/ {s/\.one//; s/\.vv:/:/}'
    CMD="/usr/bin/sed -i '/$namingType\.one\..*\.vv:/ {s/\.one//; s/\.vv:/:/}'"
fi;

#echo -e "VM IDs:\n$VMs"
#echo -e "Image IDs:\n$images"
#echo "--------"
#echo $CMD
#exit
function updateVM(){
    echo "Job: $1 -- $2 "
    for VM in $(seq $1 $2); do
        echo "$VM"
        #read _
        out=$(onedb show-body vm --id $VM 2>/dev/null) || continue
        if [[ $out == "undefined method \`first' for nil:NilClass" ]]; then continue; fi;
        EDITOR="$CMD" onedb update-body vm --id $VM
    done;
}

function updateImage(){
    echo "Job: $@"
    for image in $@; do
        echo "$image"
        out=$(onedb show-body image --id $image 2>/dev/null) || continue
        if [[ $out == "undefined method \`first' for nil:NilClass" ]]; then continue; fi;
        #read _
        EDITOR="$CMD" onedb update-body image --id $image
    done;
}

if (( dryRun )); then
    if (( REVERSE )); then
        #'/stg2\..*[0-9]:/ {s/stg2/stg2.one/; s/:/.vv:/}
        CMD="/usr/bin/sed \"/<SOURCE><\!\[CDATA\[$namingType\..*[0-9]:/ {s/$namingType/$namingType.one/; s/:/.vv:/}\""
    else
        #'/stg2\.one\..*\.vv:/ {s/\.one//; s/\.vv:/:/}'
        CMD="/usr/bin/sed \"/<SOURCE><\!\[CDATA\[$namingType\.one\..*\.vv:/ {s/\.one//; s/\.vv:/:/}\""
    fi;
    if [[ -d "$outDir/db.bak" ]]; then
        rm -rf "$outDir/db.bak/"
    fi
    mkdir $outDir/db.bak
    function updateVM(){
        echo "Job: $1 -- $2 "
        for VM in $(seq $1 $2); do
            #echo "$VM"
            #echo "$CMD"
            #sleep 1
            #read _
            out=$(onedb show-body vm --id $VM 2>/dev/null) || continue
            if [[ $out == "undefined method \`first' for nil:NilClass" ]]; then continue; fi;
            echo "$out" > $outDir/db.bak/$VM.vm
            #set -x
            DIFF=$(eval "$CMD $outDir/db.bak/$VM.vm" | diff $outDir/db.bak/$VM.vm -)
            echo -e "$VM $DIFF"
            #set +x
        done;
    }
    function updateImage(){
        echo "Job: $@"
        for image in $@; do
            #echo "$image"
            #read _
            out=$(onedb show-body image --id $image 2>/dev/null) || continue
            if [[ $out == "undefined method \`first' for nil:NilClass" ]]; then continue; fi;
            echo "$out" > $outDir/db.bak/$image.image
            DIFF=$(eval "$CMD $outDir/db.bak/$image.image" | diff $outDir/db.bak/$image.image -)
            echo -e "$image $DIFF"
        done;
    }
fi;


JOBS=4
job_range=$((lastVM/JOBS))
start=0
for i in $(seq 1 $JOBS); do
    end=$((start+job_range-1))
    if (( i == $JOBS)); then end=$lastVM; fi;
    updateVM $start $end &
  #  for VM in $(seq $start $end); do
  #      echo "$VM"
  #      #read _
  #      #EDITOR="$CMD" onedb update-body vm --id $VM
  #  done;
    start=$((start+job_range))
done;
wait
echo "---------- VMs Done ----------"
echo $images
imageLen=${#imageArray[@]}
job_range=$((imageLen/JOBS))
start=0
for i in $(seq 1 $JOBS); do
    end=$((start+job_range-1))
    if (( i == $JOBS)); then job_range=$imageLen; fi;
    #echo "${imageArray[@]:$start:$job_range}"
    updateImage "${imageArray[@]:$start:$job_range}" &
    start=$((start+job_range))
done;
wait;
trap - EXIT
