rm -r yaml
mkdir -p yaml

project=$1
ps_num=$2
worker_num=$3


nfs_server="192.168.50.18"
nfs_path=/home/kakaozhang/kubernetes/nfs_shared

python3 template_yaml.py nfs_tf.yaml.jinja2 "server=${nfs_server} path=${nfs_path}" yaml/nfs_tf_${project}.yaml
kubectl create -f yaml/nfs_tf_${project}.yaml


host_ips=""
worker_ips=""

# config and run ps
for ps_i in $(seq 1 ${ps_num})
do
    ps_i=$(($ps_i-1))
    pod_image=tensorflow/tensorflow:latest-py3
    pod_index=${ps_i}
    pod_ports=$(($ps_i+ 2222))
    pod_host_path=/workspace/
    pod_name=pod-tensorflow-ps-${pod_index}
    pod_labels_name=tensorflow-ps-${pod_index}
    pod_labels_role=pod
    pod_container_name=ps

    python3 template_yaml.py pod_tf.yaml.jinja2 "index=${pod_index} name=${pod_name} \
    labels_name=${pod_labels_name} labels_role=${pod_labels_role}  image=${pod_image} \
    container_name=${pod_container_name} ports=${pod_ports} host_path=${pod_host_path}" \
    yaml/pod_tf_${project}_ps_${ps_i}.yaml

    kubectl create -f yaml/pod_tf_${project}_ps_${ps_i}.yaml

    svc_name=svc-tensorflow-ps-${pod_index}
    svc_labels_name=tensorflow-ps
    svc_labels_role=svc
    svc_port=$(($ps_i+ 2222))
    svc_targetPort=${pod_ports}
    svc_selector_name=${pod_labels_name}

    python3 template_yaml.py service_tf.yaml.jinja2 "labels_name=${svc_labels_name} labels_role=${svc_labels_role} \
    name=${svc_name} port=${svc_port} targetPort=${svc_targetPort} selector_name=${svc_selector_name} "\
    yaml/service_tf_${project}_ps_${ps_i}.yaml

    kubectl create -f yaml/service_tf_${project}_ps_${ps_i}.yaml

    host_ips="${host_ips},${svc_name}:${svc_port}"

done

# config and run worker
for worker_i in $(seq 1 ${worker_num})
do
    worker_i=$(($worker_i-1))
    pod_image=tensorflow/tensorflow:latest-py3
    pod_index=${worker_i}
    pod_ports=$(($worker_i+ 3333))
    pod_host_path=/workspace/
    pod_name=pod-tensorflow-worker-${pod_index}
    pod_labels_name=tensorflow-worker-${pod_index}
    pod_labels_role=pod
    pod_container_name=worker

    python3 template_yaml.py pod_tf.yaml.jinja2 "index=${pod_index} name=${pod_name} \
    labels_name=${pod_labels_name} labels_role=${pod_labels_role}  image=${pod_image} \
    container_name=${pod_container_name} ports=${pod_ports} host_path=${pod_host_path}" \
    yaml/pod_tf_${project}_worker_${worker_i}.yaml

    kubectl create -f yaml/pod_tf_${project}_worker_${worker_i}.yaml

    svc_name=svc-tensorflow-worker-${pod_index}
    svc_labels_name=tensorflow-worker-svc
    svc_labels_role=svc
    svc_port=$(($worker_i+ 3333))
    svc_targetPort=${pod_ports}
    svc_selector_name=${pod_labels_name}

    python3 template_yaml.py service_tf.yaml.jinja2 "labels_name=${svc_labels_name} labels_role=${svc_labels_role} \
    name=${svc_name} port=${svc_port} targetPort=${svc_targetPort} selector_name=${svc_selector_name} "\
    yaml/service_tf_${project}_worker_${worker_i}.yaml

    kubectl create -f yaml/service_tf_${project}_worker_${worker_i}.yaml

    worker_ips="${worker_ips},${svc_name}:${svc_port}"

done

echo -------------PODS---------------
kubectl get pods -o wide
echo -------------SERVICE---------------
kubectl get svc
echo -------------PV---------------
kubectl get pv
echo -------------PVC---------------
kubectl get pvc




#for ps_i in $(seq 1 ${ps_num})
#do
#    ps_i=$(($ps_i-1))
#    pod_index=${ps_i}
#    pod_ports=$(($ps_i+ 2222))
#    pod_name=pod-tensorflow-ps-${pod_index}
#
#    #host_ips="${svc_name}:${svc_port},${host_ips}"
#    host_ips="${host_ips},$(kubectl get pod ${pod_name} --template={{.status.podIP}}):${pod_ports}"
#done
#
#for worker_i in $(seq 1 ${worker_num})
#do
#    worker_i=$(($worker_i-1))
#    pod_index=${worker_i}
#    pod_ports=$(($worker_i+ 3333))
#    pod_name=pod-tensorflow-worker-${pod_index}
#
#    #worker_ips="${svc_name}:${svc_port},${worker_ips}"
#    worker_ips="${worker_ips},$(kubectl get pod ${pod_name} --template={{.status.podIP}}):${pod_ports}"
#done


# config and run ps
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

for ps_i in $(seq 1 ${ps_num})
do
    ps_i=$(($ps_i-1))
    pod_index=${ps_i}

    echo "nohup kubectl exec -it pod-tensorflow-ps-${pod_index} -- python3 ${pod_host_path}tf_test.py --ps_hosts=$host_ips --worker_hosts=$worker_ips --job_name=ps --task_index=${ps_i} > tf_task_logs/pod-tensorflow-ps-${pod_index}.logs 2>&1&" >> start_tensorflow.sh

    echo "sleep 0.5s" >> start_tensorflow.sh
   #nohup kubectl exec  pod-tensorflow-ps-${pod_index} \
   #  -- python3 ${pod_host_path}tf_test.py \
   #  --ps_hosts=$host_ips \
   #  --worker_hosts=$worker_ips \
   #  --job_name=ps --task_index=${ps_i} \
   #  > pod-tensorflow-ps-${pod_index}.logs 2>&1&


done

echo "sleep 5s" >> start_tensorflow.sh

for worker_i in $(seq 1 ${worker_num})
do
    worker_i=$((worker_i-1))
    pod_index=${worker_i}

    echo "nohup kubectl exec -it pod-tensorflow-worker-${pod_index} -- python3 ${pod_host_path}tf_test.py --ps_hosts=$host_ips --worker_hosts=$worker_ips  --job_name=worker --task_index=${worker_i} > tf_task_logs/pod-tensorflow-worker-${pod_index}.logs 2>&1&"  >> start_tensorflow.sh

    echo "sleep 0.5s" >> start_tensorflow.sh
    #nohup kubectl exec  pod-tensorflow-worker-${pod_index} \
    # -- python3 ${pod_host_path}tf_test.py \
    # --ps_hosts=$host_ips \
    # --worker_hosts=$worker_ips \
    # --job_name=worker --task_index=${worker_i} \
    # > pod-tensorflow-worker-${pod_index}.logs 2>&1&


done
