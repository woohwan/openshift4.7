Importing OVA  
```  
RHCOS_OVA='Downloads/rhcos-4.10.3-x86_64-vmware.x86_64-hv19.ova'  
LIBRARY='rhcos-hv19'  
TEMPLATE_NAME='rhcos-hv19-4.10.13'  
govc session.login -u 'user:password@host'  
govc library.create "${LIBRARY}"  
govc library.import -n "${TEMPLATE_NAME}" "${LIBRARY}" "${RHCOS_OVA}"  
```  