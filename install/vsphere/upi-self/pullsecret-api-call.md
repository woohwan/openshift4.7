### 참고: https://access.redhat.com/solutions/4844461  

### Issue:  
How can I automate downloading the pull secret needed for OpenShift 4 installs.  

### Resolution  
The api for https://cloud.redhat.com/openshift/ is at https://api.openshift.com/. The pull secret endpoint is POST /api/accounts_mgmt/v1/access_token

You need to authenticate using a Bearer token, which you can get from the second section at https://cloud.redhat.com/openshift/token. This link details using a long lived access token, which is obtained there too.  

```  
$ export BEARER=$(curl \
--silent \
--data-urlencode "grant_type=refresh_token" \
--data-urlencode "client_id=cloud-services" \
--data-urlencode "refresh_token=${OFFLINE_ACCESS_TOKEN}" \
https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token | \
jq -r .access_token)

$ curl -X POST https://api.openshift.com/api/accounts_mgmt/v1/access_token --header "Content-Type:application/json" --header "Authorization: Bearer $BEARER" | jq

{
  "auths": {
    "cloud.openshift.com": {
      "auth": "<snip>",
      "email": "<user's email>"
    },
    "quay.io": {
      "auth": "<snip>",
      "email": "<user's email>"
    },
    "registry.connect.redhat.com": {
      "auth": "<snip>",
      "email": "<user's email>"
    },
    "registry.redhat.io": {
      "auth": "<snip>",
      "email": "<user's email>"
    }
  }
}  
```  

