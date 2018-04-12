#!/usr/local/bin/perl
use English;
use strict;
my $pwd=qx(pwd);
chomp($pwd);
my $logfile="$pwd/test.log";
my $cfgfile="$pwd/airflow/airflow.cfg";
sub toLog {
    open(LOG,">>$logfile") or
	print "Cannot open  $logfile for writing: $ERRNO\n";
    foreach my $item (@ARG) {
	my $tmp = $item;
	chomp($tmp);
	print LOG ("$tmp\n");
    }
    close(LOG);
}

open (LOG, ">$logfile") or
    print "Cannot open $logfile for writing: $ERRNO\n";

my $resp=qx(sudo apt-get update -y);
toLog("running apt-get update",$resp);

#install pip
$resp=qx(sudo apt-get install python-pip -y);
toLog("Installing pip",$resp);

sleep(10);
# upgrade pip
$resp=qx(sudo -H pip install --upgrade pip ); 
toLog("Upgrading pip");

#install airflow
$resp=qx(sudo -H pip install apache-airflow);
toLog("Installing airflow master",$resp);
sleep(30);
#install postgres
$resp=qx(sudo apt-get install postgresql postgresql-contrib -y);
toLog("Installing postgres",$resp);

#install pscopg2
$resp=qx(sudo -H pip install psycopg2);
toLog("Installing pscopg2",$resp);

#install celery redis bundle
$resp=qx(sudo -H pip install -U "celery[redis]");
toLog("Installing celery and redis bundle",$resp);
#install redis server
$resp=qx(sudo apt-get -y install redis-server);
toLog("installing redis server",$resp);
$resp=qx(sudo service redis start);
toLog("starting redis service", $resp);

#start airflow db
$resp=qx(airflow initdb);
toLog("start airflow db",$resp);

#create user, pass & db in prosgres

$resp=qx(sudo -u postgres createdb  airflow);
toLog("Creating database airflow");
$resp=qx(sudo -u postgres psql -c "create user airflow with  password 'airflow';");
toLog("creating user airflow with password airflow",$resp);
$resp=qx(sudo -u postgres psql -c "grant all privileges on database airflow to airflow;");
toLog("granting privileges to airflow database",$resp);


if ( -e $cfgfile){
#need to change cfg in airflow.cfg
  $resp=qx(cp $cfgfile ${cfgfile}_original);
  toLog("baking up cfg original file",$resp);
  open(READ, "${cfgfile}_original") 
             || die "Can't open ${cfgfile}_original for reading($!)";
  open(WRITE, ">$cfgfile") 
             || die "Can't open $cfgfile for writing($!)";
  my $line;
  while(defined ($line=<READ>)){
	    chomp($line);
            if ($line =~ /sql_alchemy_conn =/){
                  $line="sql_alchemy_conn = postgresql://airflow:airflow\@localhost:5432/airflow";
            }elsif($line =~ /broker_url =/){
                  $line="broker_url = redis://redis:6379/1";
            }elsif($line =~ /executor =/){
                  $line="executor = CeleryExecutor";
            }elsif($line =~ /result_backend =/){
                  $line="result_backend = db+postgresql://airflow:airflow\@localhost:5432/airflow";
            }
print WRITE "$line\n";
  }
close(WRITE) || die "cannot close($!)";                  
close(READ) || die "cannot close($!)";

#Restart airflow db
$resp=qx(airflow initdb);
toLog("Restart airflow db",$resp);

$resp=qx(nohup airflow webserver  >> ~/airflow/logs/webserver.log &);
toLog("Start webserver", $resp);

$resp=qx(nohup airflow worker  >> ~/airflow/logs/worker.log &);
toLog("Start Celery Worker");
}
close(LOG) or
    print "Cannot close $logfile: $ERRNO\n";

