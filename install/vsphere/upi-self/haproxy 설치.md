# API 및 Ingress Load balancer로 사용

## Syslog Server 설정 
$ dnf install -y rsyslog
$ systemctl status rsyslog

haproxy rule 추가
$ vi /etc/rsyslog.conf
local2.*                       /var/log/haproxy.log

$ systemctl restart rsyslog

## HA Proxy 설정
$ dnf install -y haproxy

backup original haproxy config file
$ cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig

config file 수정
$ cp haproxy.cfg /etc/haproxy/haproxy.cfg

SELinux 설정 변경

If you want to allow haproxy to connect any
Then you must tell SELinux about this by enabling the 'haproxy_connect_any' boolean.
Do 
setsebool -P haproxy_connect_any 1
--------  OR ------------------------------------------------------------------------
$ ssetsebool -P haproxy_connect_any 1

If you want to allow /usr/sbin/haproxy to bind to network port 22623
Then you need to modify the port type.
Do
$ semanage port -a -t haproxy_t -p tcp 22623



$ systemctl enable haproxy
$ systemctl start haproxy
$ systemctl status haproxy
 


참고: haproxy 에서 사용 가능한 알고리즘 

roundrobin : 순차적으로 분배 (최대 연결 가능 서버 4128개)
static-rr : 서버에 부여된 가중치(weight)에 따라서 분배
leastconn : 접속 수가 가장 적은 서버로 분배
source : 운영 중인 서버의 가중치를 나눠서 접속자 IP를 해싱(hashing)해서 분배
uri : 접속하는 URI를 해싱해서 운영 중인 서버의 가중치를 나눠서 분배(URI의 길이 또는 depth로 해싱)
rdp-cookie : TCP 요청에 대한 RDP 쿠키에 따른 분배