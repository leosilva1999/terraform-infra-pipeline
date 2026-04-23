#!/bin/bash
echo ECS_CLUSTER=titools-cluster >> /etc/ecs/ecs.config

yum update -y
amazon-linux-extras install nginx1 -y
systemctl enable nginx
systemctl start nginx

sudo nano /usr/local/bin/update_nginx_upstream.sh

TASK_IP=$(curl -s http://localhost:51678/v1/tasks \
  | grep -oP '"IPv4Addresses":\s*\["\K[0-9.]+' | head -n 1)

if [ -z "$TASK_IP" ]; then
  echo "Task IP não encontrado"
  exit 1
fi

cat <<EOF > /etc/nginx/conf.d/titools.conf
server {
    listen 80;

    location / {
        proxy_pass http://$TASK_IP:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

systemctl reload nginx

chmod +x /usr/local/bin/update_nginx_upstream.sh

# espera ECS iniciar tasks
sleep 60

/usr/local/bin/update_nginx_upstream.sh

echo "*/1 * * * * /usr/local/bin/update_nginx_upstream.sh" | crontab -