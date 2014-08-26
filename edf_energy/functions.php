<?php
// ######################
// Requirements:
// * config.php : the configuration file for connecting to Postgresql DB
// * Database with it's tables: cpu, job
// ######################

// The configuration file for connecting to Postgresql DB
include 'config.php';

// A select query
$select = "select id_job_slurm, cpu, node, cpus, user_nni
            from job, cpu
            where job.node = cpu.node_name
            and strpos(job.cpus, cpu.cpu) > 0
            and time_unix between start_time and end_time
            order by id_job_slurm
            ";
$result = pg_query($conn1, $select);
// $val_b : array which have data like job_id, cpu, user, etc
$val_b = array();
while ($row2 = pg_fetch_array($result)) {
    $k=$row2['id_job_slurm'];
    $m=$row2['cpu'];
    $val_b[$k]["DATA"] = $row2;
    if (!isset($val_b[$k]["CPUS"]) || !in_array($m, $val_b[$k]["CPUS"])) {
        $val_b[$k]["CPUS"][] = $m;
    }
}

// printing informations
echo "<center>
<table border='1' style='text-align:center;'>
  <tr>
    <th>Job ID</th>
    <th>Job Efficiency</th>
    <th>#CPUS alloc</th>
    <th>#CPUS used</th>
    <th>#CPUS lost</th>
    <th>User NNI</th>
  </tr>";
    reset($val_b);
    foreach ($val_b as $job => $donnees) {
        $job_id=$donnees['DATA']['id_job_slurm'];
        $Efficiency=count($donnees['CPUS']) * 100 / str_word_count($donnees['DATA']['cpus']);
        $CPUS_alloc=str_word_count($donnees['DATA']['cpus']);
        $num_cpu_used=count($donnees['CPUS']);
        $cpus_lost=str_word_count($donnees['DATA']['cpus'])-count($donnees['CPUS']);
        $user_nni=$donnees['DATA']['user_nni'];
        $cpu_used=implode($donnees['CPUS']," ");
    echo "
      <tr>
        <td>".$job_id."</td>
        <td>".$Efficiency." %</td>
        <td>".$CPUS_alloc."</td>
        <td>".$num_cpu_used."</td>
        <td>".$cpus_lost."</td>
        <td>".$user_nni."</td>
      </tr> ";
    }
echo '</table></center><br>-<br>';
