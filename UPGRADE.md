# Upgrade from 2.0.4 to 3.0.0

Replace all 3PAR driver files in your cluster with the ones in `interop` branch.  
Before running any renaming scripts, read their `--help`, then do a dry run for each and verify it's output.  
First run 3PAR renaming script `scripts/3parRename.py <IP> <USER> <PASSWORD_FILE>`.  
Then run `scripts/ONRename.sh -n <NAMING_TYPE>` on your ON controller node (has to have onedb access).  
Order matters!  
Finally replace the 3PAR driver with the 3.0.0 version.  
