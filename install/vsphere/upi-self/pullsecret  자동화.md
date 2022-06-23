### disconnected cluster deploy 3번 참조

1. https://console.redhat.com/openshift/token 에서 토큰을 받아 oflfine_access_token 로 저장한다  

2. make_ocp_pullsecret.sh를 실행하여 ocp_pullsecret.json를 생성한다.  

3. make_merge_pullsecret.sh을 수행하여 pullsecret_config.json과 ocp_pullsecret.json을 merge 하여 merged_pullsecret.json 생성한다.  

pullsecret_config.json은 mirror registry의 auth 정보이다.  

3.1 Create a pull secret that can be used to push content into the container registry  
```podman login -u openshift -p redhat --authfile $HOME/pullsecret_config.json registry.steve-ml.net:5000```  

```   
{
        "auths": {
                "registry.steve-ml.net:5000": {
                        "auth": "b3BlbnNoaWZ0OnJlZGhhdA==",
                        "email": "whpark@saltware.co.kr"
                }
        }
}
```  

4. merged_pullsecret.json의 내용을 install-config.yaml의 pullSecret항목에 copy & paste한다.
