#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="--context cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Secret dbpassword + pod db-pod env from secret (ns dev-db)" {
  echo '1' >> /var/work/tests/result/all
  NS="-n dev-db"
  val=$(kubectl get secret dbpassword $CTX $NS -o jsonpath='{.data.pwd}' 2>/dev/null | base64 -d 2>/dev/null)
  ref=$(kubectl get po db-pod $CTX $NS -o json 2>/dev/null | jq -r '.spec.containers[0].env[]? | select(.name=="MYSQL_ROOT_PASSWORD") | .valueFrom.secretKeyRef.name' | head -1)
  if [[ "$val" == "my-secret-pwd" ]] && [[ "$ref" == "dbpassword" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "secret val=$val envref=$ref"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. ConfigMap app-config → env COLOR in pod cfg-pod (ns app-cfg)" {
  echo '1' >> /var/work/tests/result/all
  NS="-n app-cfg"
  cmv=$(kubectl get cm app-config $CTX $NS -o jsonpath='{.data.COLOR}' 2>/dev/null)
  # pod must get the variable from configmap (via env or envFrom)
  img=$(kubectl get po cfg-pod $CTX $NS -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  ref=$(kubectl get po cfg-pod $CTX $NS -o json 2>/dev/null | jq -r '[.spec.containers[0].envFrom[]?.configMapRef.name] + [.spec.containers[0].env[]?.valueFrom.configMapKeyRef.name] | map(select(.=="app-config")) | length')
  if [[ "$cmv" == "blue" ]] && [[ -n "$img" ]] && [[ "$ref" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "cm COLOR=$cmv pod img=$img cmref=$ref"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. ConfigMap config from file mounted in deployment app-z (ns app-z, /appConfig)" {
  echo '1' >> /var/work/tests/result/all
  NS="-n app-z"
  cm=$(kubectl get cm config $CTX $NS -o jsonpath='{.metadata.name}' 2>/dev/null)
  mp=$(kubectl get deploy app-z $CTX $NS -o json 2>/dev/null | jq -r '.spec.template.spec.containers[0].volumeMounts[]? | select(.mountPath=="/appConfig") | .mountPath' | head -1)
  vol=$(kubectl get deploy app-z $CTX $NS -o json 2>/dev/null | jq -r '.spec.template.spec.volumes[]? | select(.configMap.name=="config") | .configMap.name' | head -1)
  if [[ "$cm" == "config" ]] && [[ "$mp" == "/appConfig" ]] && [[ "$vol" == "config" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "cm=$cm mountPath=$mp vol=$vol"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Pod prod-app mounts configmap and secret (ns prod-apps)" {
  echo '1' >> /var/work/tests/result/all
  NS="-n prod-apps"
  cmvol=$(kubectl get po prod-app $CTX $NS -o json 2>/dev/null | jq -r '[.spec.volumes[]? | select(.configMap.name=="prod-config")] | length')
  secvol=$(kubectl get po prod-app $CTX $NS -o json 2>/dev/null | jq -r '[.spec.volumes[]? | select(.secret.secretName=="prod-secret")] | length')
  if [[ "$cmvol" -ge 1 ]] && [[ "$secvol" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "prod-app configmap-vol=$cmvol secret-vol=$secvol"; result=1; fi
  [ "$result" == "0" ]
}
