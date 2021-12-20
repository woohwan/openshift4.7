steve-ml.net의 Host Zone에 관련 node 등록
ocp 4.4 이상부터는 etcd SRV 등록이 필요 없음.
( 참고: https://access.redhat.com/solutions/5309701



; The api identifies the IP of your load balancer.
api.ocp4		    300     IN	    A   172.20.2.228	
api-int.ocp4		300     IN	    A	172.20.2.228

; The wildcard also identifies the load balancer.
*.apps.ocp4		    300     IN	    A	172.20.2.228

; Create an entry for the bootstrap host.
bootstrap.ocp4	    300     IN	    A	172.20.2.253

; Create entries for the control plane nodes.
cp0.ocp4            300     IN      A   172.20.2.235
cp1.ocp4            300     IN      A   172.20.2.236
cp2.ocp4            300     IN      A   172.20.2.237

; Create entries for the comput nodes.
cptnod0.ocp4        300     IN      A   172.20.2.245
cptnod1.ocp4        300     IN      A   172.20.2.246

------------------ PTR ----------------------------
; The syntax is "last octet" and the host must have an FQDN
; with a trailing dot.

;
228	    300     IN	    PTR	    api.ocp4.steve-ml.net.
228	    300     IN	    PTR	    api-int.ocp4.steve-ml.net.

235     300     IN      PTR     cp0.ocp4.steve-ml.net.
236	    300     IN	    PTR	    cp1.ocp4.steve-ml.net.
237	    300     IN	    PTR	    cp2.ocp4.steve-ml.net.
;
253	    300     IN	    PTR	    bootstrap.ocp4.steve-ml.net.

;
245	    300     IN	    PTR	    cptnod0.ocp4.steve-ml.net.
246	    300     IN	    PTR	    cptnod1.ocp4.steve-ml.net.
;
