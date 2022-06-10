### Chapter 2: Designing Containerized Applications for OpenShift    

Common changes to Dockerfiles required to run a container on RHOCP:  
- Root group permissions on files that are read or written by processes in the container.  
- Files that are executable must have group execute permissions.  
- Processes running in the container must not listen on privileged ports (ports below 1024).  

#### Injecting Data from Secrets and Configuration Maps into Applications  
```  
oc set env deployment/mydcname --from configmap/myconf  
oc set volume deployment/mydcname --add \
-t configmap -m /path/to/mount/volume \
--name myvol --configmap-name myconf
```  

### Chapter 3  
#### Authenticating OpenShift to Private Registries  
```  
[user@host ~]$ oc create secret docker-registry registrycreds \
--docker-server registry.example.com \
--docker-username youruser \
--docker-password yourpassword  

# alternative way using he authentication token from the podman login command:  
[user@host ~]$ oc create secret generic registrycreds \
--from-file .dockerconfigjson=${XDG_RUNTIME_DIR}/containers/auth.json \
--type kubernetes.io/dockerconfigjson  

You then link the secret to the default service account from your project:  
[user@host ~]$ oc secrets link default registrycreds --for pull 

To use the secret to access an S2I builder image, link the secret to the builder service account from your project:  
[user@host ~]$ oc secrets link builder registrycreds  
```  

