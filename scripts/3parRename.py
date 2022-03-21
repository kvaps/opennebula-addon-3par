#!/usr/bin/python3

from hpe3parclient import client,exceptions
import sys
from argparse import ArgumentParser

parser = ArgumentParser()

parser.add_argument("-r", "--reverse",action='store_true',help='Rename all 3PAR devices back to the old naming scheme')
parser.add_argument("-d", "--dry-run",action='store_true',dest="dryrun",help="Do not rename, only show how names would be changed")
parser.add_argument("-i", "--insecure",action='store_false',dest="secure",help="Allow insecure SSL")
parser.add_argument("-p", "--port",action='store',default=8080,help="WSAPI Server Port number")
parser.add_argument("-P", "--proto",default="https",help="WSAPI Server protocol [HTTP/HTTPS]")
parsed, args = parser.parse_known_args()
#print(args)

port = parsed.port
proto = parsed.proto.lower()
ip = args[0]
username = args[1]
pw_file = args[2]

api = proto + "://" + args[0] + ":" + str(port) + "/api/v1"
f = open(args[2],"r")
pw = f.readline().splitlines()[0]
#print(args," ",api," ",args[1])
print(api," ",args[1])

cl = client.HPE3ParClient(api, False, parsed.secure, None, True)
cl.setSSHOptions(args[0], args[1], pw)
try:
    cl.login(args[1], pw)
except exceptions.HTTPUnauthorized as ex:
    print("Login failed.")
    print(ex)
    exit(1)

try:
    print(cl.getStorageSystemInfo().get('name'))
    if parsed.dryrun:
        print("Dry run")
    else:
        print("Live run")
    if parsed.secure:
        print("Secure")
    else:
        print("Insecure")
except Exception as ex:
    print(ex)
    exit;

i = input("Everything in order? [y/n]")
if  i != "y":
    cl.logout()
    exit()

try:
    vvs = cl.getVolumes()
    vvsets = cl.getVolumeSets()
except Exception as ex:
    print(ex)
    exit(1)

pr=False
rejects = []
rejectsSet = []
def rename():
    global pr
    for vv in vvs.get('members'):
        name=vv.get('name')
        splitName = name.split('.')
        if len(splitName) < 3:
            rejects.append(vv.get('name'))
            continue
        if splitName[1] == "one":
            del splitName[1]
        else:
            rejects.append(vv.get('name'))
            continue;
        pr=True
        if splitName[len(splitName)-2] == "checkpoint":
            splitName[len(splitName)-2]="cp"
        if splitName[len(splitName)-1] == "vv":
            del splitName[len(splitName)-1]
        if splitName[len(splitName)-1].startswith("vv-"):
            afterDash = splitName[len(splitName)-1].split('-')[1]
            splitName[len(splitName)-2] += "-" + afterDash
            del splitName[len(splitName)-1]
        nameChanged = ".".join(splitName)
        print(name + "->" + nameChanged)
        if parsed.dryrun:
            continue
        try:
            cl.modifyVolume(name, {'newName':nameChanged})
        # except exceptions.HTTPBadRequest:
        # except exceptions.HTTPForbidden:
        # except exceptions.HTTPInternalServerError:
        # except exceptions.HTTPConflict:
        except Exception as ex:
            print(ex)

    for vvset in vvsets.get('members'):
        name=vvset.get('name')
        splitName = name.split('.')
        if len(splitName) < 3:
            rejects.append(vvset.get('name'))
            continue
        if splitName[1] == "one":
            del splitName[1]
        else:
            rejects.append(vvset.get('name'))
            continue;
        pr=True
        if splitName[len(splitName)-1] == "vvset":
            del splitName[len(splitName)-1]
        nameChanged = ".".join(splitName)
        print(name + "->" + nameChanged)
        if parsed.dryrun:
            continue
        try:
            cl.modifyVolumeSet(name, newName=nameChanged )
        except Exception as ex:
            print(ex)

def renameReverse():
    global pr
    for vv in vvs.get('members'):
        name=vv.get('name')
        splitName = name.split('.')
        if len(splitName) < 2 or splitName[len(splitName)-1].startswith('vv'):
            rejects.append(vv.get('name'))
            continue
        if '' in splitName:
            rejects.append(vv.get('name'))
            continue
        pr=True
        splitName.insert(1,"one")
        if splitName[len(splitName)-1] == "cp":
            splitName[len(splitName)-1]="checkpoint"
        if '-' in splitName[len(splitName)-1]:
            last = splitName[len(splitName)-1].split('-')
            splitName[len(splitName)-1]=last[0]
            splitName.append("vv-" + last[1])
        else:
            splitName.append("vv")
        nameChanged = ".".join(splitName)
        print(name + "->" + nameChanged)
        if parsed.dryrun:
            continue
        try:
            cl.modifyVolume(name, {'newName':nameChanged})
        except Exception as ex:
            print(ex)

    for vvset in vvsets.get('members'):
        name=vvset.get('name')
        splitName = name.split('.')
        if len(splitName) < 2 or splitName[len(splitName)-1].startswith('vv'):
            rejects.append(vvset.get('name'))
            continue
        if '' in splitName:
            rejects.append(vvset.get('name'))
            continue
        pr=True
        splitName.insert(1,"one")
        splitName.insert(len(splitName),"vvset")
        nameChanged = ".".join(splitName)
        print(name + "->" + nameChanged)
        if parsed.dryrun:
            continue
        try:
            cl.modifyVolumeSet(name, newName=nameChanged )
        except Exception as ex:
            print(ex)

if parsed.reverse:
    print("reverse")
    renameReverse()
else:
    print("normal")
    rename()

if pr:
    print("\n\nRejects")
    print(rejects)
    print(rejectsSet)

cl.logout()
