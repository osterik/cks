#!/bin/bash
echo " *** worker pc cka lab 108 k8s-1"
export KUBECONFIG=/root/.kube/config

echo "Waiting for at least two nodes to be available..."
while true; do
    node_count=$(kubectl get no --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -ge 2 ]; then
        echo "Found $node_count node(s), proceeding..."
        break
    fi
    sleep 5
done

# Lower the attractiveness of node 2 so that pods are assigned to the controlplane
# first by default. Requred to force user to select correct node on test #3
echo "*** Creating the reserve pod on node=node_2..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: reserve
  namespace: kube-system
spec:
  nodeSelector:
    node: node_2
  containers:
  - name: reserve
    image: registry.k8s.io/pause:3.10
    resources:
      requests:
        cpu: "1500m"
        memory: "1200Mi"
EOF

kubectl wait --for=condition=Ready pod/reserve --timeout=120s
echo "*** Pod 'reserve' created succesfully"
