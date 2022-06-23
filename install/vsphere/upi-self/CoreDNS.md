#### 변경  

github.com에 대해 forward 설정

1. 
```  
echo << EOF > dns.yml
apiVersion: operator.openshift.io/v1
kind: DNS
metadata:
  name: default
spec:
  servers:
  - name: cloudfare-dns
    # forward할 domain 기입
    zones:
      - github.com
      - maven.repository.redhat.com
    forwardPlugin:
      upstreams:
        - 1.1.1.1
EOF
```    
2. View the ConfigMap
```  
oc get configmap/dns-default -n openshift-dns -o yaml
```  


```  
POD=$(kubectl get pod -n openshift-insights | awk '{ print $1 }' | grep -v NAME)
kubectl exec -ti $POD -n openshift-insights -- bash
```  