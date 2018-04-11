#!/usr/local/bin/perl
use English;
use strict;

$logfile="~/test.log";
$cfgfile="~/airflow/airflow.cfg";
sub toLog {
    open(LOG,">>$logfile") or
	print "Cannot open $log_file for writing: $ERRNO\n";
    foreach my $item (@ARG) {
	my $tmp = $item;
	chomp($tmp);
	print LOG ("$tmp\n");
    }
    close(LOG);
}

open (LOG, ">$logfile") or
    print "Cannot open $log_file for writing: $ERRNO\n";

$resp=qx(sudo apt-get update -y);
toLog("running apt-get update",$resp);

#install pip
$resp=(sudo apt-get install python-pip -y);
toLog("Installing pip",$resp);

#install airflow
$resp=qx(pip install git+https://github.com/apache/incubator-airflow);
toLog("Installing airflow master",$resp);

#install postgres
$resp=qx(sudo apt-get install postgresql postgresql-contrib -y);
toLog("Installing postgres",$resp);

#install pscopg2
$resp=qx(pip install psycopg2);
toLog("Installing pscopg2",$resp);

#install celery redis bundle
$resp=qx(pip install -U "celery[redis]");
toLog("Installing celery and redis bundle",$resp);

#start airflow db
$resp=qx(airflow initdb);
toLog("start airflow db",$resp);

#create user, pass & db in prosgres
$resp=qx(sudo -u postgres createuser airflow);
toLog("Creating user for prosgres",$resp);

$resp=qx(sudo -u postgres createdb  airflow);

$resp=qx(alter user postgres with encrypted password 'airflow');
toLog("Creating password for postgres",$resp);
qx(\q);

#need to change cfg in airflow.cfg
$resp=qa(cp $cfgfile ${cfgfile}_original);
toLog("baking up cfg original file",$resp);

open(READ, $confile) 
             || die "Can't open $confile for reading($!)";
while(defined ($line=<READ>)){
	    chomp($line);
            if ($line =~ /sql_alchemy_conn =/){
                  $line="sql_alchemy_conn = postgresql://airflow:airflow@localhost:5432/airflow";
            }elif($line =~ /broker_url =/){
                  $line="broker_url = redis://redis:6379/1";
            }elif($line =~ /executor =/){
                  $line="executor = CeleryExecutor";
            }elif($line =~ /result_backend =/){
                  $line="result_backend = db+postgresql://airflow:airflow@localhost:5432/airflow";
            }
                 
close(READ) || die "cannot open to read $confile $ERRNO\n";

close(WRITE) || die "cannot close($!)";

close(LOG) or
    print "Cannot close $log_file: $ERRNO\n";
