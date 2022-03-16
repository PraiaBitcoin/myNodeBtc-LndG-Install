#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
        echo 'Tenha certeza que não está logado como root.' >&2
        exit 1
fi

cd /home/admin
git clone https://github.com/cryptosharks131/lndg.git
cd lndg
sudo apt install virtualenv
virtualenv -p python3 .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python initialize.py
read -p "Anote a senha acima. Usuario: lndg-admin"
.venv/bin/python jobs.py
sudo bash nginx.sh
sudo systemctl restart uwsgi.service

cat << EOF > /home/admin/lndg/jobs.sh
#!/bin/bash
/home/admin/lndg/.venv/bin/python /home/admin/lndg/jobs.py
EOF

cat << EOF > /home/admin/lndg/rebalancer.sh
#!/bin/bash
/home/admin/lndg/.venv/bin/python /home/admin/lndg/rebalancer.py
EOF

cat << EOF > /home/admin/lndg/htlc_stream.sh
#!/bin/bash
/home/admin/lndg/.venv/bin/python /home/admin/lndg/htlc_stream.py
EOF

sudo bash -c 'cat << EOF > /etc/systemd/system/jobs-lndg.service
[Unit]
Description=Run Jobs For Lndg
[Service]
User=admin
Group=admin
ExecStart=/usr/bin/bash /home/admin/lndg/jobs.sh
StandardError=append:/var/log/lnd_jobs_error.log
EOF'

sudo bash -c 'cat << EOF > /etc/systemd/system/jobs-lndg.timer
[Unit]
Description=Run Lndg Jobs Every 20 Seconds
[Timer]
OnBootSec=300
OnUnitActiveSec=20
AccuracySec=1
[Install]
WantedBy=timers.target
EOF'

sudo bash -c 'cat << EOF > /etc/systemd/system/rebalancer-lndg.service
[Unit]
Description=Run Rebalancer For Lndg
[Service]
User=admin
Group=admin
ExecStart=/usr/bin/bash /home/admin/lndg/rebalancer.sh
StandardError=append:/var/log/lnd_rebalancer_error.log
RuntimeMaxSec=3600
EOF'

sudo bash -c 'cat << EOF > /etc/systemd/system/rebalancer-lndg.timer
[Unit]
Description=Run Lndg Rebalancer Every 20 Seconds
[Timer]
OnBootSec=315
OnUnitActiveSec=20
AccuracySec=1
[Install]
WantedBy=timers.target
EOF'

sudo bash -c 'cat << EOF > /etc/systemd/system/htlc-stream-lndg.service
[Unit]
Description=Run HTLC Stream For Lndg
[Service]
User=admin
Group=admin
ExecStart=/usr/bin/bash /home/admin/lndg/htlc_stream.sh
StandardError=append:/var/log/lnd_htlc_stream_error.log
Restart=on-failure
RestartSec=60s
[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl enable jobs-lndg.timer
sudo systemctl start jobs-lndg.timer
sudo systemctl enable rebalancer-lndg.timer
sudo systemctl start rebalancer-lndg.timer
sudo systemctl enable htlc-stream-lndg.service
sudo systemctl start htlc-stream-lndg.service

echo
echo "Concluído. Acesse a interface via 127.0.0.1:8889 ou localhost:8889"