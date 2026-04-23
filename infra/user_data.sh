#!/bin/bash

# ECS config
echo ECS_CLUSTER=titools-cluster >> /etc/ecs/ecs.config

# Pacotes
yum update -y
amazon-linux-extras install nginx1 -y

# NGINX
systemctl enable nginx
systemctl start nginx


cat <<'EOF' > /usr/local/bin/update_nginx_upstream.sh
#!/bin/bash

TASK_IP=$(curl -s http://localhost:51678/v1/tasks \
  | grep -oP '"IPv4Addresses":\s*\["\K[0-9.]+' | head -n 1)

if [ -z "$TASK_IP" ]; then
  echo "Task IP não encontrado"
  exit 1
fi

cat <<EOC > /etc/nginx/conf.d/titools.conf
server {
    listen 80;

    location / {
        proxy_pass http://$TASK_IP:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOC

systemctl reload nginx
EOF

chmod +x /usr/local/bin/update_nginx_upstream.sh


until curl -s http://localhost:51678/v1/tasks | grep -q IPv4Addresses; do
  echo "Aguardando task subir..."
  sleep 5
done


/usr/local/bin/update_nginx_upstream.sh


echo "*/1 * * * * /usr/local/bin/update_nginx_upstream.sh" | crontab -