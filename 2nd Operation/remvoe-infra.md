####  원복  
```  
# ingress controller
oc patch ingresscontroller/default -n openshift-ingress-operator --type json --patch '[{"op": "remove", "path": "/spec/nodePlacement/tolerations" }]'  
oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"replicas": 2}}'  


# registry

```  