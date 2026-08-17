#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="--context cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. User john: CSR approved + Role developer + can create pods in development" {
  echo '1' >> /var/work/tests/result/all
  NS="-n development"
  cond=$(kubectl get csr john-developer $CTX -o jsonpath='{.status.conditions[?(@.type=="Approved")].type}' 2>/dev/null)
  cani=$(kubectl auth can-i create pods --as=john $CTX $NS 2>/dev/null)
  cang=$(kubectl auth can-i get pods --as=john $CTX $NS 2>/dev/null)
  if [[ "$cond" == "Approved" ]] && [[ "$cani" == "yes" ]] && [[ "$cang" == "yes" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "csr=$cond can-create=$cani can-get=$cang"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. SA pvviewer + ClusterRole/CRB: SA can list persistentvolumes; pod uses SA" {
  echo '1' >> /var/work/tests/result/all
  NS="-n default"
  sa=$(kubectl get sa pvviewer $CTX $NS -o jsonpath='{.metadata.name}' 2>/dev/null)
  cani=$(kubectl auth can-i list persistentvolumes --as=system:serviceaccount:default:pvviewer $CTX 2>/dev/null)
  podsa=$(kubectl get po pvviewer $CTX $NS -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  if [[ "$sa" == "pvviewer" ]] && [[ "$cani" == "yes" ]] && [[ "$podsa" == "pvviewer" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "sa=$sa can-list-pv=$cani pod.sa=$podsa"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. SA pod-sa + Role/RoleBinding in team-elephant: SA can list pods; pod uses SA" {
  echo '1' >> /var/work/tests/result/all
  NS="-n team-elephant"
  sa=$(kubectl get sa pod-sa $CTX $NS -o jsonpath='{.metadata.name}' 2>/dev/null)
  cani=$(kubectl auth can-i list pods --as=system:serviceaccount:team-elephant:pod-sa $CTX $NS 2>/dev/null)
  podsa=$(kubectl get po pod-sa $CTX $NS -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  if [[ "$sa" == "pod-sa" ]] && [[ "$cani" == "yes" ]] && [[ "$podsa" == "pod-sa" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "sa=$sa can-list-pods=$cani pod.sa=$podsa"; result=1; fi
  [ "$result" == "0" ]
}
