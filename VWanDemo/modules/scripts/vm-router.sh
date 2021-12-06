#!/bin/bash
sed -ir 's/#* *net.ipv4.ip_forward *= *[01]/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
sysctl -p

DEBIAN_FRONTEND=noninteractive apt-get update -yqqq
DEBIAN_FRONTEND=noninteractive apt-get install strongswan bird -yqqq

cat > /etc/bird/bird.conf <<EOF
router id {{LocalBGPPeer}};
protocol device {
    scan time 10;
}
protocol static static_bgp {
    route 0.0.0.0/0 via {{PrivateIP}};
}
protocol kernel {
    export filter {
        if proto = "static_bgp" then reject;
        krt_prefsrc = {{PrivateIP}};
        accept;
    };
    import none;
}
protocol bgp vwan
{
    keepalive time 20;
    hold time 60;
    graceful restart aware;
    import all;
    export where proto = "static_bgp";
    local {{LocalBGPPeer}} as {{LocalASN}};
    neighbor {{RemoteBGPPeer}} as {{RemoteASN}};
}
EOF

cat > /etc/ipsec.conf <<EOF
config setup
    uniqueids=yes
    strictcrlpolicy=no
conn %default
    authby=secret
    ike=aes256-sha2_256-modp1024!
    esp=aes256-sha2_256!
    keyingtries=0
    dpdaction=restart
conn vwan0
    left={{PrivateIP}}
    leftsubnet=0.0.0.0/0
    right={{VWanPIP}}
    rightsubnet=0.0.0.0/0
    auto=start
    mark=%unique
    leftupdown="/etc/ipsec-vti.sh 0 {{RemoteBGPPeer}}/30 {{LocalBGPPeer}}/30"
EOF

cat > /etc/ipsec.secrets <<EOF
{{PrivateIP}} {{VWanPIP}} : PSK "{{SharedKey}}"
EOF

cat > /etc/strongswan.d/charon.conf <<EOF
charon {
    install_routes = no
}
EOF

cat > /etc/ipsec-vti.sh <<EOF
#!/bin/bash
set -o nounset
set -o errexit

IP=\$(which ip)
IPTABLES=\$(which iptables)

PLUTO_MARK_OUT_ARR=(\${PLUTO_MARK_OUT//// })
PLUTO_MARK_IN_ARR=(\${PLUTO_MARK_IN//// })

VTI_TUNNEL_ID=\${1}
VTI_REMOTE=\${2}
VTI_LOCAL=\${3}

LOCAL_IF="\${PLUTO_INTERFACE}"
VTI_IF="vti\${VTI_TUNNEL_ID}"

# ipsec overhead is 73 bytes
VTI_MTU=$((1460-73))

case "\${PLUTO_VERB}" in
    up-client)
        \${IP} link add \${VTI_IF} type vti local \${PLUTO_ME} remote \${PLUTO_PEER} okey \${PLUTO_MARK_OUT_ARR[0]} ikey \${PLUTO_MARK_IN_ARR[0]}
        \${IP} addr add \${VTI_LOCAL} remote \${VTI_REMOTE} dev "\${VTI_IF}"
        \${IP} link set \${VTI_IF} up mtu \${VTI_MTU}
        sysctl -w net.ipv4.conf.\${VTI_IF}.disable_policy=1
        sysctl -w net.ipv4.conf.\${VTI_IF}.rp_filter=2 || sysctl -w net.ipv4.conf.\${VTI_IF}.rp_filter=0
        \${IPTABLES} -t mangle -I FORWARD -o \${VTI_IF} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        \${IPTABLES} -t mangle -I INPUT -p esp -s \${PLUTO_PEER} -d \${PLUTO_ME} -j MARK --set-xmark \${PLUTO_MARK_IN}
        \${IP} route flush table 220
        ;;
    down-client)
        \${IP} tunnel del "\${VTI_IF}"
        ;;
esac

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.\${LOCAL_IF}.disable_xfrm=1
sysctl -w net.ipv4.conf.\${LOCAL_IF}.disable_policy=1
EOF

chmod +x /etc/ipsec-vti.sh

systemctl restart bird

ipsec restart
ipsec up vwan0