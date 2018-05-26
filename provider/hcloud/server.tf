resource "hcloud_server" "host" {
  depends_on = ["hcloud_ssh_key.ssh_key"]

  count         = "${var.hetzner_server_count}"

  name          = "${format(var.hetzner_hostname_format, count.index + 1)}"
  datacenter    = "${var.hetzner_datacenter}"
  image         = "${var.hetzner_image}"
  server_type   = "${var.hetzner_server_type}"
  ssh_keys      = ["${hcloud_ssh_key.ssh_key.id}"]
  iso           = "${var.hetzner_iso_image}"
  backup_window = "${var.hetzner_backup_window}"
  keep_disk     = "${var.hetzner_keep_disk}"
  rescue        = "${var.hetzner_rescue}"
  user_data     = <<EOT
#cloud-config
groups:
  - ${var.hetzner_group_name}: [root,sys]
users:
  - name: ${var.hetzner_user_name}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin, ${var.hetzner_group_name}
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ${file("~/.ssh/${var.hetzner_ssh_key_name}.pub")}
hostname: ${format(var.hetzner_hostname_format, count.index + 1)}
fqdn: ${format(var.hetzner_hostname_format, count.index + 1)}.${var.hetzner_domain}
manage_etc_hosts: true
apt_update: true
apt_upgrade: true
EOT

  connection {
    user = "root"
    private_key = "${file("~/.ssh/${var.hetzner_ssh_key_name}")}"
    type = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      # Applications
      "echo 'Update Package Lists...'",
      "sudo apt-get -y update",
      "echo 'Add additional apps ...'",
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "echo 'Apt Upgrade ...'",
      "sudo apt-get upgrade -y",
      "echo 'Upgrade finished...'",
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "echo 'Adding to repository: ppa:certbot/certbot'",
      "sudo add-apt-repository -y ppa:certbot/certbot",
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "echo 'Update New Package Lists...'",
      "sudo apt-get update -y",
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "sudo echo 'Installing packages ufw unattended-upgrades sendmail ${join(" ", var.hetzner_apt_install_packages)}'",
      "sudo apt-get install -y ufw unattended-upgrades sendmail docker.io ${join(" ", var.hetzner_apt_install_packages)}",
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",

      # Setup cron jobs in crontab
      "echo 'Setting up Crontab...'",
      "(sudo crontab -l ; echo '${file("${path.module}/cronjobs")}') | sudo crontab -",

      # Setup unattended upgrades
      "echo 'Setting up Unattended Upgrades...'",
      "sudo touch /etc/apt/apt.conf.d/20auto-upgrades",
      "sudo echo 'APT::Periodic::Update-Package-Lists \"1\";'              | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades",
      "sudo echo 'APT::Periodic::Download-Upgradeable-Packages \"1\";'     | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades",
      "sudo echo 'APT::Periodic::AutocleanInterval \"3\";'                 | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades",
      "sudo echo 'APT::Periodic::Unattended-Upgrade \"1\";'                | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades",
      "sudo chmod +w /etc/apt/apt.conf.d/50unattended-upgrades",
      "sudo echo 'Unattended-Upgrade::Remove-Unused-Dependencies \"true\";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades",
      "sudo echo 'Unattended-Upgrade::Automatic-Reboot \"true\";'          | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades",
      "sudo echo 'Unattended-Upgrade::Automatic-Reboot-Time \"01:00\";'    | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades",
      "sudo echo 'Unattended-Upgrade::Mail \"${var.hetzner_email}\";'      | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades",

      # Setup IP Spoofing protection
      "echo 'Setting up IP Spoofing protection...'",
      "sudo echo '# IP Spoofing protection'                       | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.all.rp_filter = 1'                | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.default.rp_filter = 1'            | sudo tee -a /etc/sysctl.conf",
      "sudo echo '# Ignore ICMP broadcast requests'               | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.icmp_echo_ignore_broadcasts = 1'       | sudo tee -a /etc/sysctl.conf",
      "sudo echo '# Disable source packet routing'                | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.all.accept_source_route = 0'      | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv6.conf.all.accept_source_route = 0'      | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.default.accept_source_route = 0'  | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv6.conf.default.accept_source_route = 0'  | sudo tee -a /etc/sysctl.conf",
      "sudo echo '# Ignore send redirects'                        | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.all.send_redirects = 0'           | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.default.send_redirects = 0'       | sudo tee -a /etc/sysctl.conf",
      "sudo echo '# Block SYN attacks'                            | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.tcp_syncookies = 1'                    | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.tcp_max_syn_backlog = 2048'            | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.tcp_synack_retries = 2'                | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.tcp_syn_retries = 5'                   | sudo tee -a /etc/sysctl.conf",
      "sudo echo '# Log Martians'                                 | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.all.log_martians = 1'             | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.icmp_ignore_bogus_error_responses = 1' | sudo tee -a /etc/sysctl.conf",
      "sudo echo '# Ignore ICMP redirects'                        | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.all.accept_redirects = 0'         | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv6.conf.all.accept_redirects = 0'         | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.conf.default.accept_redirects = 0'     | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv6.conf.default.accept_redirects = 0'     | sudo tee -a /etc/sysctl.conf",
      "sudo echo '# Ignore Directed pings'                        | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv4.icmp_echo_ignore_all = 1'              | sudo tee -a /etc/sysctl.conf",

      # Disable IPv6
      "sudo echo 'net.ipv6.conf.all.disable_ipv6 = 1'             | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv6.conf.default.disable_ipv6 = 1'         | sudo tee -a /etc/sysctl.conf",
      "sudo echo 'net.ipv6.conf.lo.disable_ipv6 = 1'              | sudo tee -a /etc/sysctl.conf",

      # Restart Networking
      "sudo sysctl -p",
      "cat /proc/sys/net/ipv6/conf/all/disable_ipv6",

      # Prevent IP Spoofing
      "echo 'Prevent IP Spoofing...'",
      "sudo sed -i 's/order hosts,bind/order bind,hosts/g' /etc/host.conf",
      "sudo sed -i 's/multi on/nospoof on/g' /etc/host.conf",

      # Adding Warning Message in the Login Banner
      "echo 'Setting Banners...'",
      "echo '!!! KEEP OUT !!! -- SYSTEM IS UNDER FULL SURVEILLANCE, WE PROSECUTE YOU DIRECTLY AND LEGALLY IN ALL CASES ---' | tee -a /etc/issue.net",
      "sudo sed -i 's/.*session optional pam_motd.so motd.*/# session optional pam_motd.so motd/g' /etc/pam.d/sshd",
      "sudo sed -i 's/.*session optional pam_motd.so noupdate.*/# session optional pam_motd.so noupdate/g' /etc/pam.d/sshd",
      "sudo sed -i 's/.*Banner.*/# Banner/g' /etc/ssh/sshd_config",

      # Restrict SSH Access
      "echo 'Restrict ssh access...'",
      "sudo sed -i 's/.*RSAAuthentication.*/RSAAuthentication yes/g' /etc/ssh/sshd_config",
      "sudo sed -i 's/.*PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config",
      "sudo sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config",
      "sudo sed -i 's/.*PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config",
      "sudo echo 'AllowUsers ${var.hetzner_user_name}@${var.hetzner_ip_access}' | sudo tee -a /etc/ssh/sshd_config",
      "sudo service ssh restart",

      # Create Swapfile
      "echo 'Setting up Swapfile...'",
      "sudo fallocate -l 2G /swapfile",
      "sudo chmod 600 /swapfile",
      "sudo mkswap /swapfile",
      "sudo swapon /swapfile",
      "sudo echo '/swapfile none swap sw 0 0'                      | sudo tee -a /etc/fstab",

      # Secure Shared Memory
      "echo 'Secure Shared Memory ...'",
      "sudo echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' | sudo tee -a /etc/fstab",

      # Bash
      "echo 'Setup User environment...'",
      "sudo cp /root/.bashrc /home/${var.hetzner_user_name}",

      # Rebooting
      "echo '....Rebooting now....'",
      "(sleep 2 && sudo reboot)&"

    ]
  }

  provisioner "local-exec" {
    command = <<EOT
curl -s -X POST "https://api.zeit.co/v2/domains/${var.hetzner_domain}/records" \
  -H "Authorization: Bearer ${var.zeit_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "${format(var.hetzner_hostname_format, count.index + 1)}",
    "type": "A",
    "value": "${self.ipv4_address}"
  }'
EOT
  }

  provisioner "local-exec" {
    when = "destroy"
    command = <<EOT
export RECORD_ID=$(curl -s "https://api.zeit.co/v2/domains/${var.hetzner_domain}/records" -H "Authorization: Bearer ${var.zeit_token}" | jq -r '.records[] | select((.value=="${self.ipv4_address}") and (.type=="A")) | .id')
echo $RECORD_ID
curl -s -X DELETE https://api.zeit.co/v2/domains/${var.hetzner_domain}/records/$RECORD_ID -H "Authorization: Bearer ${var.zeit_token}"
EOT
  }
}

