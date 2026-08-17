#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="--context cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Node has label disk=ssd" {
  echo '1' >> /var/work/tests/result/all
  v=$(kubectl get nodes $CTX -o jsonpath='{.items[*].metadata.labels.disk}' 2>/dev/null)
  if echo "$v" | grep -qw ssd; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "node label disk='$v'"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Pod sel (nodeSelector disk=ssd) is Running" {
  echo '1' >> /var/work/tests/result/all
  NS="-n sched"
  ph=$(kubectl get pod sel $CTX $NS -o jsonpath='{.status.phase}' 2>/dev/null)
  ns=$(kubectl get pod sel $CTX $NS -o jsonpath='{.spec.nodeSelector.disk}' 2>/dev/null)
  if [[ "$ph" == "Running" ]] && [[ "$ns" == "ssd" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "sel phase=$ph nodeSelector.disk=$ns"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Pod aff (nodeAffinity) is Running" {
  echo '1' >> /var/work/tests/result/all
  NS="-n sched"
  ph=$(kubectl get pod aff $CTX $NS -o jsonpath='{.status.phase}' 2>/dev/null)
  af=$(kubectl get pod aff $CTX $NS -o jsonpath='{.spec.affinity.nodeAffinity}' 2>/dev/null)
  if [[ "$ph" == "Running" ]] && [[ -n "$af" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "aff phase=$ph nodeAffinity set=$([[ -n "$af" ]] && echo yes || echo no)"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Pod res has requests/limits and is Running" {
  echo '1' >> /var/work/tests/result/all
  NS="-n sched"
  ph=$(kubectl get pod res $CTX $NS -o jsonpath='{.status.phase}' 2>/dev/null)
  lc=$(kubectl get pod res $CTX $NS -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
  lm=$(kubectl get pod res $CTX $NS -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null)
  if [[ "$ph" == "Running" ]] && [[ -n "$lc" ]] && [[ -n "$lm" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "res phase=$ph limits.cpu=$lc limits.memory=$lm"; result=1; fi
  [ "$result" == "0" ]
}

@test "5. PriorityClass high-prio (1000) used by pod prio" {
  echo '1' >> /var/work/tests/result/all
  NS="-n sched"
  val=$(kubectl get priorityclass high-prio $CTX -o jsonpath='{.value}' 2>/dev/null)
  pc=$(kubectl get pod prio $CTX $NS -o jsonpath='{.spec.priorityClassName}' 2>/dev/null)
  ph=$(kubectl get pod prio $CTX $NS -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$val" == "1000" ]] && [[ "$pc" == "high-prio" ]] && [[ "$ph" == "Running" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "high-prio value=$val prio priorityClassName=$pc phase=$ph"; result=1; fi
  [ "$result" == "0" ]
}

@test "6. Node tainted (dedicated=special:NoSchedule) and pod tol tolerates it" {
  echo '1' >> /var/work/tests/result/all
  NS="-n sched"
  keys=$(kubectl get nodes $CTX -o jsonpath='{.items[*].spec.taints[*].key}' 2>/dev/null)
  eff=$(kubectl get nodes $CTX -o jsonpath='{.items[*].spec.taints[*].effect}' 2>/dev/null)
  ph=$(kubectl get pod tol $CTX $NS -o jsonpath='{.status.phase}' 2>/dev/null)
  if echo "$keys" | grep -qw dedicated && echo "$eff" | grep -qw NoSchedule && [[ "$ph" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "taint keys='$keys' effects='$eff' tol phase=$ph"; result=1; fi
  [ "$result" == "0" ]
}
