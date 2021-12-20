# 별도의 private network을 구성하지 않고, 회사 Network을 이용해서 cluster 구성



Base Domain: steve-ml.net 
cluster name: ocp4

- DNS: AWS Route53 domain: steve-ml.net
- LB: 172.20.2.228, lb.ocp4, haproxy
  향후  HA로 구성할 경우, 228. 229 사용

- 회사 DHCP를 수정할 수 없으므로, RHCOS OVA의 vm template을 static ip 사용



