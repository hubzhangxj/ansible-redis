#!/bin/bash
set -x
if [ $# -lt 3 ]; then
    echo "Usage: client_start.sh {init | test}  <ip_address> <redis_inst_number> <keep_alive> <pipe_num>"
    exit 0
fi

#BASE_DIR=`pwd`
#REDIS_TEST_DIR=${BASE_DIR}
#######################################################################################
# Notes:
#  To start client tests
#  Usage: client_start.sh {init | test} <ip_addr> <start_cpu_num> <redis_inst> <keep-alive> <pipe_num>
#######################################################################################

ip_addr=${2}
base_port_num=7000
start_cpu_num=${3}
redis_inst_num=${4}
keep_alive=${5}
pipeline=${6}

data_num=10000000
data_size=10
key_space_len=10000

if [[ ${pipeline} -eq 100 ]] ; then
    echo "Change num_of_req to 100000000"
    data_num=100000000
fi
    
if [ "$1" == "init" ] ; then
    #Step 1: Prepare data

    echo 1 > /proc/sys/net/ipv4/tcp_timestamps
    echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
    echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle
    echo 2048 65000 > /proc/sys/net/ipv4/ip_local_port_range
    echo 2621440 > /proc/sys/net/core/somaxconn
    echo 2621440 > /proc/sys/net/core/netdev_max_backlog
    echo 2621440 > /proc/sys/net/ipv4/tcp_max_syn_backlog
   # echo 1 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_time_wait
   # echo 2621440 > /proc/sys/net/netfilter/nf_conntrack_max
    ulimit -n 1024000
    #data_num=10000
    #data_size=128
    set -x
    python ./scripts/generate_inputdata.py ./input_data ${data_num} ${data_size}
   
    let "redis_inst_num--"
    #redis_inst_num=0
    for index in $(seq 0 ${redis_inst_num})
    do
        echo "call redis-cli to initialize data for redis-${index}"
        port=`expr ${base_port_num} + ${index} + ${start_cpu_num}`
        echo "flushdb"  |  redis-cli -h ${ip_addr} -p ${port} --pipe
 #       sed -i 's/\' \\\'/g' ./input_data
        cat ./input_data | redis-cli -h ${ip_addr} -p ${port} --pipe
        echo "call redis-cli to initialize data for redis-${index} finished"
    done

elif [ "$1" == "test" ] ; then
    rm redis_benchmark_log*

    let "redis_inst_num--"
    for index in $(seq 0 ${redis_inst_num})
    do
        port=`expr ${base_port_num} + ${index} + ${start_cpu_num}`
        taskindex=`expr 17 + ${index}`
        #taskend=`expr 6 + ${taskindex}`
        echo "call redis-benchmark to test redis-${index}"
        
        #if testing perfrmance of twemproxy+redis cluster,you should uncomment next line#
        #port=22121

        taskset -c ${taskindex} redis-benchmark -h ${ip_addr} -p ${port} -c 50 -n ${data_num} -d ${data_size} -k ${keep_alive} -r ${key_space_len} -P ${pipeline} -t get > redis_benchmark_log_${port} & 
       #### test SET command
       let "taskindex++"
       taskset -c ${taskindex} redis-benchmark -h ${ip_addr} -p ${port} -c 50 -n ${data_num} -d ${data_size} -k ${keep_alive} -r ${key_space_len} -P ${pipeline} -t set 
#> redis_benchmark_log_${port} &

        #redis-benchmark -h ${ip_addr} -p ${port} -c 50 -n ${data_num} -d ${data_size} -k ${keep_alive} -r ${key_space_len} -P ${pipeline} -t get > redis_benchmark_log_${port} &
    done

    echo "Please check results under ${REDIS_TEST_DIR} directory"
    echo "You could use scripts/analysis_qps_lat.py to get qps and latency from logs"

    #popd > /dev/null
else 
    echo "parameter should be {init | test} "
fi

echo "**********************************************************************************"

