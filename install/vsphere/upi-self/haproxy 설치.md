# API 및 Ingress Load balancer로 사용  

## Syslog Server 설정   
```
$ dnf install -y rsyslog
$ systemctl status rsyslog
```
haproxy rule 추가  
```
$ vi /etc/rsyslog.conf
local2.*                       /var/log/haproxy.log

$ systemctl restart rsyslog
```  
## HA Proxy 설정  
```
$ dnf install -y haproxy

backup original haproxy config file
$ cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig

config file copy
$ cp haproxy.cfg /etc/haproxy/haproxy.cfg
```  
config file 검증  
`$ haproxy -f /etc/haproxy/haproxy.cfg -c`

## SELinux 설정 변경  

If you want to allow haproxy to connect any  
Then you must tell SELinux about this by enabling the 'haproxy_connect_any' boolean.  
Do   
setsebool -P haproxy_connect_any 1  

$ ssetsebool -P haproxy_connect_any 1  

위 command 수행 시 haproxy 전체 port binding 가능  
--------  OR ----------------------------------------------------  
아래 command는 binding port 를 구체적으로 명시  

If you want to allow /usr/sbin/haproxy to bind to network port 22623  
Then you need to modify the port type.  
Do  
$ semanage port -a -t haproxy_t -p tcp 22623  

http port 추가 (Binding 되지 않을 경우 수행)   
-----------------------------------------------------
### 현재 SELinux에서 허용하고 있는 port 확인  
```
$ semanage port -l |grep http_port_t
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988

$ semanage port -a -t http_port_t -p tcp 22623
$ semanage port -a -t http_port_t -p tcp 6443

$ systemctl enable haproxy
$ systemctl start haproxy
$ systemctl status haproxy
```

# haproxy log 회전주기 수정
```
$ vi /etc/logrotate.d/haproxy 
/var/log/haproxy.log  {
    daily
    rotate 10
    create 0644 nobody nobody
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        /bin/systemctl restart rsyslog.service > /dev/null 2>/dev/null || true
    endscript
}
```
속성 설명  
rotate 10 (10-daily ->90일에 한번씩 회전)  
create 0644 nobody nobody -> 로그파일 정리 후 새로운 로그파일 생성  
dateext -> logrotate실행 뒤 로그파일에 날짜 부여  
missingok : 로그파일이 없을경우 에러메시지를 출력하고 다음으로 실행합니다  
notifempty : 로그파일의 내용이 없을경우 rotate 하지 않습니다  
compress : 로그파일을 압축합니다  
sharedscripts : 여러개의 로그파일을 스크립트로 공유하여 실행합니다  
postrotate : 실행 후 스크립트 파일 실행합니다(rsyslog재시작)  

`$ systemctl restart rsyslog`

### Listening port 확인  
```
$ netstat -tnlp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22623           0.0.0.0:*               LISTEN      40333/haproxy
tcp        0      0 0.0.0.0:9000            0.0.0.0:*               LISTEN      40333/haproxy
tcp        0      0 0.0.0.0:6443            0.0.0.0:*               LISTEN      40333/haproxy
tcp        0      0 0.0.0.0:111             0.0.0.0:*               LISTEN      1/systemd
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      40333/haproxy
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1197/sshd
tcp        0      0 127.0.0.1:631           0.0.0.0:*               LISTEN      1200/cupsd
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      40333/haproxy
tcp6       0      0 :::111                  :::*                    LISTEN      1/systemd
tcp6       0      0 :::22                   :::*                    LISTEN      1197/sshd
tcp6       0      0 ::1:631                 :::*                    LISTEN      1200/cupsd

$  ss -nltp  
State       Recv-Q      Send-Q           Local Address:Port            Peer Address:Port     Process
LISTEN      0           128                    0.0.0.0:22623                0.0.0.0:*         users:(("haproxy",pid=40333,fd=10))
LISTEN      0           128                    0.0.0.0:9000                 0.0.0.0:*         users:(("haproxy",pid=40333,fd=7))
LISTEN      0           128                    0.0.0.0:6443                 0.0.0.0:*         users:(("haproxy",pid=40333,fd=9))
LISTEN      0           128                    0.0.0.0:111                  0.0.0.0:*         users:(("rpcbind",pid=967,fd=4),("systemd",pid=1,fd=43))
LISTEN      0           128                    0.0.0.0:80                   0.0.0.0:*         users:(("haproxy",pid=40333,fd=12))
LISTEN      0           128                    0.0.0.0:22                   0.0.0.0:*         users:(("sshd",pid=1197,fd=5))
LISTEN      0           5                    127.0.0.1:631                  0.0.0.0:*         users:(("cupsd",pid=1200,fd=10))
LISTEN      0           128                    0.0.0.0:443                  0.0.0.0:*         users:(("haproxy",pid=40333,fd=11))
LISTEN      0           128                       [::]:111                     [::]:*         users:(("rpcbind",pid=967,fd=6),("systemd",pid=1,fd=47))
LISTEN      0           128                       [::]:22                      [::]:*         users:(("sshd",pid=1197,fd=7))
LISTEN      0           5                        [::1]:631                     [::]:*         users:(("cupsd",pid=1200,fd=9))
```  

### firewall 수정  
port 오픈: 6443, 22623, 80, 443  
```
$ firewall-cmd --get-default-zone
public

$ firewall-cmd --permanent --add-port={80/tcp,443/tcp,9000/tcp,6443/tcp,22623/tcp}
$ firewall-cmd --reload
$ firewall-cmd --list-ports
80/tcp 443/tcp 6443/tcp 22623/tcp
```

### 참고: haproxy 에서 사용 가능한 알고리즘  

roundrobin : 순차적으로 분배 (최대 연결 가능 서버 4128개)  
static-rr : 서버에 부여된 가중치(weight)에 따라서 분배  
leastconn : 접속 수가 가장 적은 서버로 분배  
source : 운영 중인 서버의 가중치를 나눠서 접속자 IP를 해싱(hashing)해서 분배  
uri : 접속하는 URI를 해싱해서 운영 중인 서버의 가중치를 나눠서 분배(URI의 길이 또는 depth로 해싱)  
rdp-cookie : TCP 요청에 대한 RDP 쿠키에 따른 분배  