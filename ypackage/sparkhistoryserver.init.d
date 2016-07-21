#!/bin/sh

unset $(/usr/bin/env | grep -E '^\s*(\w+)=(.*)$' | grep -Ewv 'PATH|SUDO_USER|SSH_CONNECTION' | cut -d= -f1)
umask 022

GS_ROOT=/grid/0/gs
GS_VAR=/grid/0/hadoop/var

if [ -d /home/gs/hadoop ] ; then
  GS_ROOT=/home/gs
  GS_VAR=/home/gs/var
fi

export LANG=en_US.UTF-8
export SHELL=/bin/sh
export JAVA_HOME=/home/gs/java/jdk64/current

YARN_CONF_DIR=$GS_ROOT/conf/hadoop/resourcemanager

if [ -f "$GS_ROOT/conf/yarn/resourcemanager/hadoop-env.sh" ] ; then
  YARN_CONF_DIR=$GS_ROOT/conf/yarn/resourcemanager
elif [ -f "$GS_ROOT/conf/yarn/hadoop-env.sh" ] ; then
  YARN_CONF_DIR=$GS_ROOT/conf/yarn
elif [ -f "$GS_ROOT/conf/hadoop/resourcemanager/hadoop-env.sh" ] ; then
  YARN_CONF_DIR=$GS_ROOT/conf/hadoop/resourcemanager
elif [ -f "$GS_ROOT/conf/current/hadoop-env.sh" ] ; then
  YARN_CONF_DIR=$GS_ROOT/conf/current
fi

HADOOP_PREFIX=$GS_ROOT/hadoop/current
CONF_DIR=$GS_ROOT/conf

if [ -d $GS_ROOT/hadoop/yarn ] ; then
  HADOOP_PREFIX=$GS_ROOT/hadoop/yarn
fi

if [ -z $2 ] ; then
  YARN_USER=mapred
else
  YARN_USER=$2
fi
HADOOP_USER=$YARN_USER

SPARK_CLASSPATH="$(ls ${HADOOP_PREFIX}/share/hadoop/hdfs/lib/yjava_servlet.jar):$(ls ${HADOOP_PREFIX}/share/hadoop/hdfs/lib/yjava_filter_logic*.jar):$(ls ${HADOOP_PREFIX}/share/hadoop/hdfs/lib/yjava_byauth*.jar):$(ls ${HADOOP_PREFIX}/share/hadoop/hdfs/lib/bouncer_auth_java*.jar):$(ls ${HADOOP_PREFIX}/share/hadoop/hdfs/lib/BouncerFilterAuth*.jar):$(ls ${HADOOP_PREFIX}/share/hadoop/hdfs/lib/yjava_servlet_filters*.jar)"

if [ -f $HADOOP_PREFIX/share/hadoop/hdfs/lib/yjava_servlet.jar ]
then
  SPARK_CLASSPATH=$SPARK_CLASSPATH:$HADOOP_PREFIX/share/hadoop/hdfs/lib/yjava_servlet.jar
fi

if [ -f $HADOOP_PREFIX/share/hadoop/hdfs/lib/yjava_filter_logic.jar ]
then
  SPARK_CLASSPATH=$SPARK_CLASSPATH:$HADOOP_PREFIX/share/hadoop/hdfs/lib/yjava_filter_logic.jar
fi

SPARK_HOME=/home/y/share/sparkhistoryserver/
SPARK_LOG_DIR=$GS_ROOT/var/log/$YARN_USER/
SPARK_PID_DIR=$GS_ROOT/var/run/$YARN_USER/

PROC=sparkhistoryserver

#     
USER=`/usr/bin/whoami`
    
if [[ $USER != "root" ]] ; then 
    exec sudo $0 "$@"
fi 
    
if [ -z "$SUDO_USER" ] ; then 
   echo "run as sudo or set SUDO_USER"
   exit 2
fi
    
if [ ! -z "$SSH_CONNECTION" ] ; then 
	REMOTE_ADDR=`echo $SSH_CONNECTION| awk '{print $1}'`
else
	REMOTE_ADDR="localhost"
fi

HADOOP_CONF_DIR=$YARN_CONF_DIR
    
export \
	USER \
	SPARK_HOME \
	HADOOP_PREFIX \
        HADOOP_CONF_DIR \
        YARN_CONF_DIR \
	SPARK_LOG_DIR \
	SPARK_DAEMON_MEMORY \
	SPARK_DAEMON_JAVA_OPTS \
	SPARK_CLASSPATH
    
export PATH=/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:$JAVA_HOME/bin:$SPARK_HOME/bin:
logger -p local7.info -t hadoop "$SUDO_USER@$REMOTE_ADDR $PROC $1 "
    
case "$1" in
	start) 
            su $HADOOP_USER  -s /bin/sh -c "$SPARK_HOME/sbin/start-history-server.sh hdfs:///mapred/sparkhistory/ "
            RET=$?
            ;;
	stop) 
	    su $HADOOP_USER  -s /bin/sh -c "$SPARK_HOME/sbin/stop-history-server.sh stop sparkhistoryserver"
            RET=$?
            ;;
	restart) 
	    $0 stop
	    sleep 1
	    $0 start
	    ;;
	*) 
	    echo "Usage: $PROC {start|stop|restart}"
	    exit 1
esac
    
exit $RET


