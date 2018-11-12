rm -rf yaml
mkdir -p yaml


project=$1
ps_pod_num=$2
ps_num=$3
worker_pod_num_cpu=$4
worker_num_cpu=$5
worker_pod_num_gpu=$6
worker_num_gpu=$7

device_num=4


nfs_server="192.168.50.18"
nfs_path=/home/kakaozhang/PycharmProjects/SirenAI
nfs_host_path=/workspace
py_script=k8s.train.k8s_train
py_path=${nfs_host_path}/speech2rig/code


# config nfs pv/pvc
python3 template_yaml.py jinjia2/pvpvc/nfs_tf.yaml.jinja2 "server=${nfs_server} path=${nfs_path}" yaml/nfs_tf_${project}.yaml
kubectl create -f yaml/nfs_tf_${project}.yaml


host_ips=""
worker_ips=""

# config and run ps
for pod_i in $(seq 1 ${ps_pod_num})
do
    pod_i=$((pod_i-1))
    pod_image=tensorflow/tensorflow:latest-py3
    pod_port_base=2222
    pod_host_path=${nfs_host_path}
    pod_name=pod-tensorflow-ps-${pod_i}
    pod_labels_name=tensorflow-ps-${pod_i}
    pod_labels_role=pod
    pod_container_name=ps
    pod_port_name=ps
    pod_port_num=${ps_num}
    pod_device=gpu
    pod_device_index=d-$((pod_i%device_num))

    python3 template_yaml.py jinjia2/pod/pod_tf_cpu.yaml.jinja2 "name=${pod_name} \
    labels_name=${pod_labels_name} labels_role=${pod_labels_role} image=${pod_image} container_name=${pod_container_name} \
    port_num=${pod_port_num} port_base=${pod_port_base} port_name=${pod_port_name} \
    host_path=${pod_host_path} device_index=${pod_device_index}" \
    yaml/pod_tf_${project}_ps_${pod_i}.yaml

    kubectl create -f yaml/pod_tf_${project}_ps_${pod_i}.yaml

    svc_name=svc-tensorflow-ps-${pod_i}
    svc_labels_name=tensorflow-ps
    svc_labels_role=svc
    svc_port_base=2222
    svc_target_port_base=${svc_port_base}
    svc_selector_name=${pod_labels_name}
    svc_port_num=${ps_num}
    svc_port_name=ps

    python3 template_yaml.py jinjia2/service/service_tf.yaml.jinja2 \
    "labels_name=${svc_labels_name} labels_role=${svc_labels_role} name=${svc_name} \
    port_num=${svc_port_num} port_name=${svc_port_name} port_base=${svc_port_base} target_port_base=${svc_target_port_base} \
    selector_name=${svc_selector_name} "\
    yaml/service_tf_${project}_ps_${pod_i}.yaml

    kubectl create -f yaml/service_tf_${project}_ps_${pod_i}.yaml

    for pod_i in $(seq 1 ${ps_num})
    do
        svc_port=$((svc_port_base+pod_i-1))
        host_ips="${host_ips},${svc_name}:${svc_port}"
    done
done

echo ${host_ips}

# config and run worker cpu
for pod_i in $(seq 1 ${worker_pod_num_cpu})
do
    pod_i=$((pod_i-1))
    pod_image=tensorflow/tensorflow:latest-py3
    pod_port_base=3333
    pod_host_path=${nfs_host_path}
    pod_name=pod-tensorflow-worker-cpu-${pod_i}
    pod_labels_name=tensorflow-worker-cpu-${pod_i}
    pod_labels_role=pod
    pod_container_name=worker
    pod_port_name=worker
    pod_port_num=${worker_num_cpu}
    pod_device_index=d-$((pod_i%device_num))

    python3 template_yaml.py jinjia2/pod/pod_tf_cpu.yaml.jinja2 "name=${pod_name} \
    labels_name=${pod_labels_name} labels_role=${pod_labels_role} image=${pod_image} container_name=${pod_container_name} \
    port_num=${pod_port_num} port_base=${pod_port_base} port_name=${pod_port_name} \
    host_path=${pod_host_path} device_index=${pod_device_index}" \
    yaml/pod_tf_${project}_worker_cpu_${pod_i}.yaml

    kubectl create -f yaml/pod_tf_${project}_worker_cpu_${pod_i}.yaml

    svc_name=svc-tensorflow-worker-cpu-${pod_i}
    svc_labels_name=tensorflow-worker-cpu
    svc_labels_role=svc
    svc_port_base=3333
    svc_target_port_base=${svc_port_base}
    svc_selector_name=${pod_labels_name}
    svc_port_num=${worker_num_cpu}
    svc_port_name=worker

    python3 template_yaml.py jinjia2/service/service_tf.yaml.jinja2 \
    "labels_name=${svc_labels_name} labels_role=${svc_labels_role} name=${svc_name} \
    port_num=${svc_port_num} port_name=${svc_port_name} port_base=${svc_port_base} target_port_base=${svc_target_port_base} \
    selector_name=${svc_selector_name} "\
    yaml/service_tf_${project}_worker_cpu_${pod_i}.yaml

    kubectl create -f yaml/service_tf_${project}_worker_cpu_${pod_i}.yaml

    for pod_i in $(seq 1 ${worker_num_cpu})
    do
        svc_port=$((svc_port_base+pod_i-1))
        worker_ips="${worker_ips},${svc_name}:${svc_port}"
    done
done


# config and run worker gpu
for pod_i in $(seq 1 ${worker_pod_num_gpu})
do
    pod_i=$((pod_i-1))
    pod_image=tensorflow/tensorflow:latest-gpu-py3
    pod_port_base=3333
    pod_host_path=${nfs_host_path}
    pod_name=pod-tensorflow-worker-gpu-${pod_i}
    pod_labels_name=tensorflow-worker-gpu-${pod_i}
    pod_labels_role=pod
    pod_container_name=worker
    pod_port_name=worker
    pod_port_num=${worker_num_gpu}
    pod_gpu_num=1
    pod_device=gpu
    pod_device_index=d-$((pod_i%device_num))

    python3 template_yaml.py jinjia2/pod/pod_tf_gpu.yaml.jinja2 "name=${pod_name} \
    labels_name=${pod_labels_name} labels_role=${pod_labels_role} image=${pod_image} container_name=${pod_container_name} \
    port_num=${pod_port_num} port_base=${pod_port_base} port_name=${pod_port_name} \
    host_path=${pod_host_path} gpu_num=${pod_gpu_num} device=${pod_device} device_index=${pod_device_index}" \
    yaml/pod_tf_${project}_worker_gpu_${pod_i}.yaml

    kubectl create -f yaml/pod_tf_${project}_worker_gpu_${pod_i}.yaml

    svc_name=svc-tensorflow-worker-gpu-${pod_i}
    svc_labels_name=tensorflow-worker-gpu
    svc_labels_role=svc
    svc_port_base=3333
    svc_target_port_base=${svc_port_base}
    svc_selector_name=${pod_labels_name}
    svc_port_num=${worker_num_gpu}
    svc_port_name=worker

    python3 template_yaml.py jinjia2/service/service_tf.yaml.jinja2 \
    "labels_name=${svc_labels_name} labels_role=${svc_labels_role} name=${svc_name} \
    port_num=${svc_port_num} port_name=${svc_port_name} port_base=${svc_port_base} target_port_base=${svc_target_port_base} \
    selector_name=${svc_selector_name} "\
    yaml/service_tf_${project}_worker_gpu_${pod_i}.yaml

    kubectl create -f yaml/service_tf_${project}_worker_gpu_${pod_i}.yaml

    for pod_i in $(seq 1 ${worker_num_gpu})
    do
        svc_port=$((svc_port_base+pod_i-1))
        worker_ips="${worker_ips},${svc_name}:${svc_port}"
    done
done


echo ${worker_ips}


echo -------------PODS---------------
kubectl get pods -o wide
echo -------------SERVICE---------------
kubectl get svc
echo -------------PV---------------
kubectl get pv
echo -------------PVC---------------
kubectl get pvc


# config tensorflow script
if [ ! -f "start_tensorflow.sh" ];then
echo ""
else
rm -rf start_tensorflow.sh
fi

echo 'if [ -d "tf_task_logs" ];then' >> start_tensorflow.sh
echo 'echo "remove tf_task_logs"' >> start_tensorflow.sh
echo 'rm -rf tf_task_logs' >> start_tensorflow.sh
echo 'mkdir tf_task_logs' >> start_tensorflow.sh
echo 'else' >> start_tensorflow.sh
echo 'mkdir tf_task_logs' >> start_tensorflow.sh
echo 'fi' >> start_tensorflow.sh



for ps_i in $(seq 1 ${ps_pod_num})
do
    ps_i=$(($ps_i-1))
    for ps_ii in $(seq 1 ${ps_num})
    do
        ps_ii=$(($ps_ii-1))
        ps_id=$(($ps_i*$ps_pod_num+$ps_ii))

        echo "nohup kubectl exec -it pod-tensorflow-ps-${ps_i} --\
        bash -c 'cd ${py_path} && python3 -m ${py_script}  --ps_ips=$host_ips --worker_ips=$worker_ips \
        --job_name=ps --task_id=${ps_id} \
        --k8s_cfg=./k8s/k8s_task/cifar10/cfg/k8s_tf.cfg \
        --agent_cfg=./k8s/k8s_task/cifar10/cfg/agent.cfg \
        --model_cfg=./k8s/k8s_task/cifar10/cfg/model.cfg' > tf_task_logs/pod-tensorflow-ps-${ps_i}-${ps_ii}.logs 2>&1&" >> start_tensorflow.sh

        echo "sleep 0.5s" >> start_tensorflow.sh

    done
done

echo "sleep 2s" >> start_tensorflow.sh

worker_index=0

for worker_i in $(seq 1 ${worker_pod_num_cpu})
do
    worker_i=$((worker_i-1))
    for worker_ii in $(seq 1 ${worker_num_cpu})
    do
        worker_ii=$(($worker_ii-1))
        worker_id=$(($worker_i*$worker_num_cpu+$worker_ii))

        echo "nohup kubectl exec -it pod-tensorflow-worker-cpu-${worker_i} --\
        bash -c 'cd ${py_path} && python3 -m ${py_script}  --ps_ips=$host_ips --worker_ips=$worker_ips \
        --job_name=worker --task_id=${worker_index} --train_type=cpu \
        --k8s_cfg=./k8s/k8s_task/cifar10/cfg/k8s_tf.cfg \
        --agent_cfg=./k8s/k8s_task/cifar10/cfg/agent.cfg \
        --model_cfg=./k8s/k8s_task/cifar10/cfg/model.cfg' > tf_task_logs/pod-tensorflow-worker-cpu-${worker_i}-${worker_ii}.logs 2>&1&" >> start_tensorflow.sh

        worker_index=$((worker_index+1))

        echo "sleep 0.5s" >> start_tensorflow.sh
    done
done


for worker_i in $(seq 1 ${worker_pod_num_gpu})
do
    worker_i=$((worker_i-1))
    for worker_ii in $(seq 1 ${worker_num_gpu})
    do
        worker_ii=$(($worker_ii-1))
        worker_id=$(($worker_i*$worker_num_gpu+$worker_ii))

        echo "nohup kubectl exec -it pod-tensorflow-worker-gpu-${worker_i} --\
        bash -c 'cd ${py_path} && python3 -m ${py_script}  --ps_ips=$host_ips --worker_ips=$worker_ips \
        --job_name=worker --task_id=${worker_index} --train_type=gpu \
        --k8s_cfg=./k8s/k8s_task/cifar10/cfg/k8s_tf.cfg \
        --agent_cfg=./k8s/k8s_task/cifar10/cfg/agent.cfg \
        --model_cfg=./k8s/k8s_task/cifar10/cfg/model.cfg' > tf_task_logs/pod-tensorflow-worker-gpu-${worker_i}-${worker_ii}.logs 2>&1&" >> start_tensorflow.sh

        worker_index=$((worker_index+1))

        echo "sleep 0.5s" >> start_tensorflow.sh
    done
done
