'''  
sudo certbot certonly --manual --preferred-challenges dns  -d "api.ocp4.steve-ml.net"  -d "*.apps.ocp4.steve-ml.net"  
```  

###  Install Let’s Encrypt Certificates to OpenShift Ingress Controller  

```  
export CERTDIR='/etc/letsencrypt/live/api.ocp4.steve-ml.net'
```  
OpenShift Ingress Controller consumes certificates stored in a secret object. The secret should be created in the openshift-ingress namespace.  

Create a secret in the openshift-ingress project:  
```  
oc -n openshift-ingress create secret tls router-certs --cert=${CERTDIR}/fullchain.pem --key=${CERTDIR}/privkey.pem

secret/router-certs created  
```  



Thereafter we update the Custom Resource for the ingress controller located in the openshift-ingress-operator project and named default:  
```  
oc get ingresscontroller -n openshift-ingress-operator  

NAME      AGE
default   28m
```  
Update the custom resource by running the command below:  
```  

ingresscontroller.operator.openshift.io/default patched  
```  
Router pods in the openshift-ingress should be restarted automatically in a short while:  
```  
oc get pods -n openshift-ingress  

NAME                             READY   STATUS    RESTARTS   AGE
router-default-888fffb58-tmqsd   0/1     Pending   0          49s
router-default-dd99777cd-pb4vx   1/1     Running   0          31m 
```  
```   
oc get pods -n openshift-ingress  
NAME                             READY   STATUS    RESTARTS   AGE
router-default-888fffb58-jhpnj   1/1     Running   0          110s
router-default-888fffb58-tmqsd   1/1     Running   0          3m19s  
```

We now have generated Let’s Encrypt SSL certificates applied on the Ingress router. The certificates also used by the applications exposed using the default route and Red Hat OpenShift Cluster Web Console and other services such as the Monitoring stack.  

### Test  
참고: https://www.tutorialworks.com/openshift-ingress/  


docker hub network util image: amouat/network-utils  
```  
oc run --rm -it utils --image=amouat/network-utils -- bash  
```  

```  
cat <<EOF > ing.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-openshift
spec:
  rules:
  - host: hello-openshift.apps.ocp4.steve-ml.net
    http:
      paths:
      - backend:
          # Forward to a Service called 'hello-openshift'
          service:
            name: hello-openshift
            port:
              number: 8080
        path: /
        pathType: Prefix
EOF
```  
자동으로 route가 생긴다. pathType이 Exact일때 route가 작성되지 않아 routing가 되지 않는다.   
```    
oc get route

NAME                    HOST/PORT                                PATH   SERVICES          PORT    TERMINATION   WILDCARD
hello-openshift-cp2qs   hello-openshift.apps.ocp4.steve-ml.net   /      hello-openshift   <all>                 None
```  

