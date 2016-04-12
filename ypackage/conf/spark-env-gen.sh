#!/usr/bin/env bash

# Set cluster specific Settings - not all clusters are configured the same
HADOOP_CONF_DIR=/home/gs/conf/hadoop/resourcemanager
cluster=$( sed -rn '/^AGGREGATOR_HOST=/ {
                                      s/AGGREGATOR_HOST=(\w+)(\w+)-agg0\.\2\..*/\1.\2/p 
                          }'  ${HADOOP_CONF_DIR}/simond.properties)
grid=$(echo $cluster | cut -d . -f 1)
color=$(echo $cluster | cut -d . -f 2)

spark_kerberos_keytab="/etc/grid-keytabs/${grid}${color}-jt1.prod.service.keytab"
spark_kerberos_principal="mapred/${grid}${color}-jt1.${color}.ygrid.yahoo.com@YGRID.YAHOO.COM"


# if it doesn't exist assume QE setup
if [ ! -e $spark_kerberos_keytab ] 
then 
  host=$(hostname)
  keytab_name=$(echo $host | cut -d . -f 1)
  spark_kerberos_keytab="/etc/grid-keytabs/$keytab_name.dev.service.keytab"
  spark_kerberos_principal="mapred/$host@DEV.YGRID.YAHOO.COM"
fi

if [ -z ${spark_history_gc_log_dir} ]
then
  spark_gc_log_file_formatted="-Xloggc:/home/gs/var/log/mapred/gc-sparkhistoryserver.log-`date +'%Y%m%d%H%M'`"
fi
spark_all_history_gc_opts="${spark_history_gc_opts} ${spark_gc_log_file_formatted}"

cat <<ENV
#!/usr/bin/env bash
# This file is sourced when running various Spark programs.
# Copy it as spark-env.sh and edit that to configure Spark for your site.

# Options read when launching programs locally with 
# ./bin/run-example or ./bin/spark-submit
# - HADOOP_CONF_DIR, to point Spark towards Hadoop configuration files
# - SPARK_LOCAL_IP, to set the IP address Spark binds to on this node
# - SPARK_PUBLIC_DNS, to set the public dns name of the driver program
# - SPARK_CLASSPATH, default classpath entries to append

# Options read by executors and drivers running inside the cluster
# - SPARK_LOCAL_IP, to set the IP address Spark binds to on this node
# - SPARK_PUBLIC_DNS, to set the public DNS name of the driver program
# - SPARK_CLASSPATH, default classpath entries to append
# - SPARK_LOCAL_DIRS, storage directories to use on this node for shuffle and RDD data
# - MESOS_NATIVE_LIBRARY, to point to your libmesos.so if you use Mesos

# Options read in YARN client mode
# - HADOOP_CONF_DIR, to point Spark towards Hadoop configuration files
# - SPARK_EXECUTOR_INSTANCES, Number of workers to start (Default: 2)
# - SPARK_EXECUTOR_CORES, Number of cores for the workers (Default: 1).
# - SPARK_EXECUTOR_MEMORY, Memory per Worker (e.g. 1000M, 2G) (Default: 1G)
# - SPARK_DRIVER_MEMORY, Memory for Master (e.g. 1000M, 2G) (Default: 512 Mb)
# - SPARK_YARN_APP_NAME, The name of your application (Default: Spark)
# - SPARK_YARN_QUEUE, The hadoop queue to use for allocation requests (Default: ‘default’)
# - SPARK_YARN_DIST_FILES, Comma separated list of files to be distributed with the job.
# - SPARK_YARN_DIST_ARCHIVES, Comma separated list of archives to be distributed with the job.

# Options for the daemons used in the standalone deploy mode:
# - SPARK_MASTER_IP, to bind the master to a different IP address or hostname
# - SPARK_MASTER_PORT / SPARK_MASTER_WEBUI_PORT, to use non-default ports for the master
# - SPARK_MASTER_OPTS, to set config properties only for the master (e.g. "-Dx=y")
# - SPARK_WORKER_CORES, to set the number of cores to use on this machine
# - SPARK_WORKER_MEMORY, to set how much total memory workers have to give executors (e.g. 1000m, 2g)
# - SPARK_WORKER_PORT / SPARK_WORKER_WEBUI_PORT, to use non-default ports for the worker
# - SPARK_WORKER_INSTANCES, to set the number of worker processes per node
# - SPARK_WORKER_DIR, to set the working directory of worker processes
# - SPARK_WORKER_OPTS, to set config properties only for the worker (e.g. "-Dx=y")
# - SPARK_HISTORY_OPTS, to set config properties only for the history server (e.g. "-Dx=y")
# - SPARK_DAEMON_JAVA_OPTS, to set config properties for all daemons (e.g. "-Dx=y")
# - SPARK_PUBLIC_DNS, to set the public dns name of the master or workers


SPARK_DAEMON_MEMORY=${spark_daemon_memory}
SPARK_DAEMON_JAVA_OPTS="-Dproc_sparkhistoryserver ${spark_all_history_gc_opts}"
SPARK_HISTORY_OPTS="-Dspark.ui.filters=yjava.servlet.filter.BouncerFilter -Dspark.history.kerberos.enabled=true -Dspark.history.kerberos.principal=${spark_kerberos_principal} -Dspark.history.kerberos.keytab=${spark_kerberos_keytab} -Dspark.history.ui.acls.enable=true -Dspark.authenticate=false -Dspark.ui.acls.enable=false -Dspark.history.retainedApplications=${spark_history_retained_applications} -Dspark.history.fs.cleaner.enabled=${spark_history_cleaner_enable} -Dspark.history.fs.cleaner.maxAge=${spark_history_cleaner_max_age} -Dspark.history.fs.cleaner.interval=${spark_history_cleaner_interval} ${spark_history_bouncer_filter_params}"

ENV
