resource "null_resource" "rancher" {

  depends_on = ["null_resource.nginx"]

  connection {
    type = "ssh"
    host  = "${element(var.connections, 0)}"
    user = "${var.user}"
    private_key = "${file("~/.ssh/${var.ssh_key_name}")}"
  }

  provisioner "remote-exec" {
    inline = [
      # Prepare nginx filesystem
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "[ -d /etc/nginx/sites-available] || sudo mkdir -p /etc/nginx/sites-available",
      "[ -d /etc/nginx/sites-enabled]   || sudo mkdir -p /etc/nginx/sites-enabled",
      "sudo touch /etc/nginx/sites-available/${format(var.hostname_format, 1)}.${var.domain}",
      "sudo chmod a+w /etc/nginx/sites-available/${format(var.hostname_format, 1)}.${var.domain}",
      "sudo ln -s /etc/nginx/sites-available/${format(var.hostname_format, count.index + 1)}.${var.domain} /etc/nginx/sites-enabled",
      "sudo rm /etc/nginx/sites-enabled/default",

      # Create Data Volume Container
      "sudo docker create --name rancher-data rancher/rancher:v2.0.0",

      # Creater Rancher v2.0.0 Container
      "sudo docker run -d --name rancher-server --restart=unless-stopped --volumes-from rancher-data -p 127.0.0.1:8080:80 rancher/rancher:v2.0.0",
    ]
  }

  # First create a simple nginx configuration to obtain letsencrypt certificate
  provisioner "file" {
    content     = <<EOT
upstream rancher {
    server 127.0.0.1:8080;
}

map $http_upgrade $connection_upgrade {
    default Upgrade;
    ''      close;
}

server {
    listen 80;
    server_name ${format(var.hostname_format, 1)}.${var.domain};

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://rancher;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        # This allows the ability for the execute shell window to remain open for up to 15 minutes. Without this parameter, the default is 1 minute and will automatically close.
        proxy_read_timeout 900s;
    }
}
EOT
    destination = "/etc/nginx/sites-available/${format(var.hostname_format, 1)}.${var.domain}"
  }

  # Obtain Letsencrypt certificate now
  provisioner "remote-exec" {
    inline = [
      "sudo certbot certonly ${var.letsencrypt_mode} --nginx -n --agree-tos --no-eff-email --email ${var.email} -d ${format(var.hostname_format, 1)}.${var.domain}",
    ]
  }

  # Enable SSL in nginx configuration
  provisioner "file" {
    content     = <<EOT
upstream rancher {
    server 127.0.0.1:8080;
}

map $http_upgrade $connection_upgrade {
    default Upgrade;
    ''      close;
}

server {
    listen 443 ssl spdy;
    server_name ${format(var.hostname_format, 1)}.${var.domain};
    ssl_certificate /etc/letsencrypt/live/${format(var.hostname_format, 1)}.${var.domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${format(var.hostname_format, 1)}.${var.domain}/privkey.pem;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://rancher;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        # This allows the ability for the execute shell window to remain open for up to 15 minutes. Without this parameter, the default is 1 minute and will automatically close.
        proxy_read_timeout 900s;
    }
}

server {
    listen 80;
    server_name ${format(var.hostname_format, 1)}.${var.domain};
    return 301 https://$server_name$request_uri;
}
EOT
    destination = "/etc/nginx/sites-available/${format(var.hostname_format, 1)}.${var.domain}"
  }

  # Reset file acess and Restart nginx
  provisioner "remote-exec" {
    inline = [
      "sudo chmod a-w /etc/nginx/sites-available/${format(var.hostname_format, 1)}.${var.domain}",
      "sudo systemctl restart nginx",
    ]
  }
}