#!/bin/bash
apt update -y
apt upgrade -y

echo steamcmd steam/license note '' | debconf-set-selections
echo steamcmd steam/question select 'I AGREE' | debconf-set-selections

add-apt-repository -y multiverse
dpkg --add-architecture i386
apt update -y
apt install steamcmd libsdl2-2.0-0 libsdl2-2.0-0:i386  -y

usr="Steam"
home="/home/$usr"
steamcmd="$home/steamcmd"
valdir="$home/valheim"
valdata="$valdir/data"
valserver="$valdir/server"
valstart="$valdir/start.sh"

useradd --create-home --shell /bin/bash --system $usr
ln -s /usr/games/steamcmd $steamcmd

mkdir $valdir
mkdir $valdata
mkdir $valserver

cat > $valstart <<EOF
#!/bin/bash
export templdpath=\$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:\$LD_LIBRARY_PATH
export SteamAppId=892970
$valserver/valheim_server.x86_64 -name "{ServerName}" -port 2456 -nographics -batchmode -world "{WorldName}" -savedir "$valdata" -password "{ServerPassword}" 
export LD_LIBRARY_PATH=\$templdpath
EOF

chmod +x $valstart

cat > /etc/systemd/system/valheim.service <<EOF
[Unit]
Description=Valheim Server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Type=simple
Restart=on-failure
RestartSec=20
TimeoutSec=600
StartLimitBurst=3
User=$usr
Group=$usr
ExecStartPre=$steamcmd +login anonymous +force_install_dir $valserver +app_update 896660 validate +exit
ExecStart=$valstart
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGINT
WorkingDirectory=$valserver
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

chown -Rf "$usr:$usr" "$home"

systemctl daemon-reload
systemctl enable valheim
systemctl start valheim