#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="--context cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. kube-apiserver is healthy (API responds)" {
  echo '1' >> /var/work/tests/result/all
  api=$(kubectl get --raw='/healthz' $CTX 2>/dev/null)
  if [[ "$api" == "ok" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "API healthz=$api (the API server is not responding; fix it first!)"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. kube-scheduler is healthy and scheduling works" {
  echo '1' >> /var/work/tests/result/all
  NS="-n kube-system"
  sched=$(kubectl get pods -l component=kube-scheduler $CTX $NS -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  ready=$(kubectl get pods -l component=kube-scheduler $CTX $NS -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  NS="-n default"
  canary=$(kubectl get pod sched-check $CTX $NS -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$sched" == "Running" ]] && [[ "$ready" == "true" ]] && [[ "$canary" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "scheduler phase=$sched ready=$ready sched-check=$canary"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. All nodes are Ready (worker kubelet fixed)" {
  echo '1' >> /var/work/tests/result/all
  total=$(kubectl get nodes $CTX --no-headers 2>/dev/null | wc -l)
  ready=$(kubectl get nodes $CTX -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c "^True$")
  if [[ "$total" -ge 2 ]] && [[ "$ready" == "$total" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "nodes total=$total ready=$ready"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Broken static pod on control plane is fixed and Running" {
  echo '1' >> /var/work/tests/result/all
  NS="-n default"
  phase=$(kubectl get pods $CTX $NS -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' 2>/dev/null | grep '^staticweb-' | awk '{print $2}' | head -1)
  if [[ "$phase" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "staticweb mirror pod phase=$phase"; result=1; fi
  [ "$result" == "0" ]
}
