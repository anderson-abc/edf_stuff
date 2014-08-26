#!/bin/bash
host="localhost"
user="G59874"
table="jem"

# Function to insert informations to database.
function sql_insert {
psql --host=$host --user=$user $table << EOF
insert into cpu(node_name, value, backup_time, time_unix, cpu) values ('$1','$value_nice','$today', '$time_nice', '$2');
EOF
}

# Function to convert jiffies into percentage
function convert_to_percentage {
	node_name=$1
	cpu_name=$2
	hz=100		# To be change according to file "clk_tk.c"
	p=$(echo "scale=10; 100 / $hz" | bc -l)
	while read line; 
	do 
	tmp=`echo $line | awk '{ print $2}'`
	time_nice=`echo $line | awk '{ print $1}'`

	if [ $tmp = "NaN" ]
	then
		value_nice=""
	else
		tmp2=`echo $tmp | sed -e 's/[eE]+*/\\*10\\^/'`	# Translate exponential (XXX E2) into numerical (var * 10^2 )
		value_nice=$(echo "scale=10; $tmp2 * $p" | bc -l)
	fi
	sql_insert $node_name $cpu_name
	done < xml_files/$2-nice.txt
}

# Function to convert rrd files into xml files
function translate_rrd_to_xml { 	# $1 == j == cpu_id
	rrdtool dump $1/cpu-nice.rrd xml_files/$1-nice.rrd.xml
}

# Function for cleaning xml files to get cpus usage values
function clean_files {		# $1 == j == cpu == cpus
	cat xml_files/$1-nice.rrd.xml | grep -E 'CEST|CET' | awk '{ print $6, $8}' | sed 's/<row><v>//' | \
	sed 's/<\/v><\/row>//' | sed '1d' | sort -k2n,2n > xml_files/$1_sed.txt
	var=$(psql -U G59874 -d jem -c "select time_unix from cpu order by time_unix desc limit 1")
	last_set=`echo $var | awk '{print $3}'`			# Last set matching to cpu table in database
	if [ $last_set = "(0" ]
	then
		last_set="0"
	fi
	awk "\$1 > $last_set{print}" xml_files/$1_sed.txt > xml_files/$1-nice.txt
}

# Main fucntion
function main {
	today=`date "+%Y-%m-%d %H:%M:%S"`
	pwd='/var/lib/collectd/rrd/'
	cd $pwd
	for i in *		# i represent nodes
	do
		cd $i
		for j in cpu*	# j represent cpus
		do
			mkdir -p xml_files
			translate_rrd_to_xml $j
			clean_files $j
			convert_to_percentage $i $j	
			rm -rf xml_files
		done
		cd ..
	done
}
main
