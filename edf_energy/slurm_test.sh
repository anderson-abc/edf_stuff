#!/bin/bash

#########################################
#	Requirements: 
# 	- Database slurm for each cluster
# 	- Account for connecting to slurm database and jem database
# 	- Jem database must containing at least 2 tables: cpu, job with their fields
# 	- Mount of cpuset in /dev
# 	- Tools: psotgresql, mysql, nodeset
#
#########################################
# Configuration for jem database connexion
host="localhost"
user="G59874"
db="jem"
table_jem_job="job"
# mdp=the password 'mpd' must be specified in .pgpass file in home directry

# Connexion to slurm database
db_slurm="slurm_acct_db"
user_slurm="slurm"
pass="09200548"
job_table="cluster_job_table"

# Function to insert data coming from cpuset into our djem atabase
function sql_insert {
psql --host=$host --user=$user $db << EOF
insert into $table_jem_job(id_job_slurm, cpus) values ('$job_id','$cpu_');
EOF
} 

# Intermediary function to avoid the application password each insertion (to check even if with .pgpass)
function interm  {
	sql_insert
}

# Collecting other informations from slurm database, to update our last set
function update_job {
t_start=$(mysql -h $host -D $db_slurm -u $user_slurm -p$pass -B -N -e "SELECT time_start FROM $job_table WHERE id_job=$1")
t_end=$(mysql -h $host -D $db_slurm -u $user_slurm -p$pass -B -N -e "SELECT time_end FROM $job_table WHERE id_job=$1")
account=$(mysql -h $host -D $db_slurm -u $user_slurm -p$pass -B -N -e "SELECT account FROM $job_table WHERE id_job=$1")
nodelist1=$(mysql -h $host -D $db_slurm -u $user_slurm -p$pass -B -N -e "SELECT nodelist FROM $job_table WHERE id_job=$1")

if [ $t_end = "0" ]; then
psql --host=$host --user=$user $db << EOF
delete from $table_jem_job where id_job_slurm=$1;
EOF
elif [ $t_end != "0" ]; then
psql --host=$host --user=$user $db << EOF
update $table_jem_job set user_nni='$account', start_time='$t_start', end_time='$t_end', node='$nodelist1' where id_job_slurm=$1;
EOF
fi
}

# Main fucntion	: Inserting to jem database and update it with data from slurm
function run {
DIR="/dev/cpuset/"
var=$(psql -U $user -d $db -c "select id_job_slurm from $table_jem_job order by id_job_slurm desc limit 1")
last_set=`echo $var | awk '{ print $3 }'`
# if empty table: no set in cpu table
if [ $last_set = "(0" ]
then
	last_set="0"
fi

if [ -d "$DIR" ]; then
	cd $DIR

	folder_list=`ls -d */`
	id_folder=`ls -d */ | sed 's/slurm//' | sed 's/\///'`

	# insert only job_id and cpu_allocated
	for i in $id_folder
	do
		if [ "$i" -gt "$last_set" ]
		then
			cd *$i
			j="slurm*"
			cd $j
			tmp1=`cat cpus`
			cpu_=`nodeset -e "cpu-[$tmp1]"`
			job_id=$i
			interm
			cd ../..
		fi
	done

	# update table with inserting other data on each job row : user, nodelist, time start, time end
	for i in $id_folder
	do
		if [ "$i" -gt "$last_set" ]
		then
			cd *$i
			j="slurm*"
			cd $j
			update_job $i
			cd ../..
		fi
	done

elif [ ! -d "$DIR" ]; then
	echo "*** You must mount cpuset in /dev/cpuset ***"
fi

}
run