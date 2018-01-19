#!/bin/bash
echo ---test----
 exit 0
#Define global APP_ROOT directory

if [ -z "${1}" ] ; then
    echo "Usage: ./run_test.sh <server ip>"
    exit 0
fi

ip="${1}"


CUR_DIR=$(cd `dirname $0` ; pwd)

echo "Try to connect server-${ip}......"

test_log_dir=${CUR_DIR}

check_redis_benchmark() {
    while [[ 1 ]]
    do
        is_running=$(ps -aux | grep redis-benchmark | grep -v grep)
        if [ -z "${is_running}" ] ; then
            return
        else
            echo "Wait for redis-benchmark done......"
            sleep 60
        fi
    done
} 

pushd ${CUR_DIR} >/dev/null

echo "Disable unused CPU..."
./enable_cpus.sh 32 64 0

echo "Stop irqbalance service firstly"
service irqbalance stop
#Bind network interrupt to specific cpus
python ./set_ethirq_cpu_affinity.py 0 15

max_inst=11
cur_inst=1

while [[ ${cur_inst} -lt ${max_inst} ]] ; 
do

start_cpu_num=17
inst_num=${cur_inst}
echo "Initialize database......"

set -x
echo "......`pwd`......."
./start_client.sh init ${ip} ${start_cpu_num} ${inst_num} 
mkdir -p ./log/${cur_inst}/

echo "Short case" > ./redis_log_${cur_inst}
./start_client.sh test ${ip} ${start_cpu_num} ${inst_num} 0 1
check_redis_benchmark
./analysis_qps_lat.py ${test_log_dir} ${inst_num} >> ./redis_log_${cur_inst}

mkdir -p  ./log/${cur_inst}/short
mv ${test_log_dir}/redis_benchmark_log*  ./log/${cur_inst}/short

echo "Basic case"
./start_client.sh test ${ip} ${start_cpu_num} ${inst_num} 1 1
check_redis_benchmark
./analysis_qps_lat.py ${test_log_dir} ${inst_num} >> ./redis_log_${cur_inst}

mkdir -p ./log/${cur_inst}/basic
mv ${test_log_dir}/redis_benchmark_log* ./log/${cur_inst}/basic

echo "Pipeline case"
./start_client.sh test ${ip} ${start_cpu_num} ${inst_num} 1 100
check_redis_benchmark
./analysis_qps_lat.py ${test_log_dir} ${inst_num} >> ./redis_log_${cur_inst}

mkdir -p ./log/${cur_inst}/pipeline
mv ${test_log_dir}/redis_benchmark_log* ./log/${cur_inst}/pipeline

let "cur_inst++"

done

echo "Enable unused CPU after test ..."
./enable_cpus.sh 32 64 1
popd >/dev/null
