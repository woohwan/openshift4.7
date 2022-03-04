/etc/named.conf 수정  

[root@dns ~]# cat /etc/named.conf  
```
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//

options {
        listen-on port 53 { any; };
        listen-on-v6 port 53 { none; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        secroots-file   "/var/named/data/named.secroots";
        recursing-file  "/var/named/data/named.recursing";
        allow-query     { any; };

        /*
         - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
         - If you are building a RECURSIVE (caching) DNS server, you need to enable
           recursion.
         - If your recursive DNS server has a public IP address, you MUST enable access
           control to limit queries to your legitimate users. Failing to do so will
           cause your server to become part of large scale DNS amplification
           attacks. Implementing BCP38 within your network would greatly
           reduce such attack surface
        */
        recursion yes;

        forwarders {
                169.254.169.253;
                8.8.8.8;
        };

        dnssec-enable yes;
        dnssec-validation yes;

        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";

        /* https://fedoraproject.org/wiki/Changes/CryptoPolicy */
        include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
        type hint;
        file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
```  
/etc/named.rfc1912.zones 에 아래 내용 추가  
```
zone "saltware.lab" IN {
        type master;
        file "saltware.lab.zone";
        allow-update { none; };
};

zone "2.20.172.in-addr.arpa" IN {
        type master;
        file "172.20.2.rev";
        allow-update { none; };
};
```  
zone file  
```
[root@dns ~]# cat /var/named/saltware.lab.zone
$TTL 3H
@       IN SOA  @ admin.saltware.lab. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
        NS      @
        A       172.20.2.230
; NCSA - A record
vcsa    IN      A       172.20.2.240
```

```
[root@dns ~]# cat /var/named/172.20.2.rev
$TTL    604800
@       IN      SOA     @ admin.saltware.lab. (
                  1     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800     ; Negative Cache TTL
)

; name server - NS record
        IN      NS      @
                A       172.20.2.230

; name server - PTR record
230     IN      PTR     saltware.lab.

; VCSA - PTR record
240     IN      PTR     vcsa.saltware.lab.
```