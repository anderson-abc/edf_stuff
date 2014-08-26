<?php
$hostname = "localhost";   
$username = "G59874";   
$database = "jem";   
$password = "09200548";  
$conn1 = pg_connect("host=$hostname dbname=$database user=$username password=$password") or die("connection failed" . pg_last_error()); 