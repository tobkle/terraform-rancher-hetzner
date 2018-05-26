resource "null_resource" "firewall" {

  count = "${var.count}"

  connection {
    type = "ssh"
    host  = "${element(var.connections, count.index + 1)}"
    user = "${var.user}"
    private_key = "${file("~/.ssh/${var.ssh_key_name}")}"
  }

  provisioner "remote-exec" {
    inline = [
      # Setup Firewall with ufw
      "echo '..................Setting Firewall rules.................'",
      "sudo sed -i 's/.*IPV6=yes.*/IPV6=no/g' /etc/default/ufw",
      "sudo ufw --force reset",

      "sudo ufw allow from 127.0.0.1",
      "sudo ufw allow from ${var.ip_access}",
      "for i in ${join(" ", var.connections)}; do sudo ufw allow from $i; done",

      "sudo ufw allow 80/tcp",
      "sudo ufw allow 443/tcp",

      "sudo ufw default deny incoming",
      "sudo ufw --force enable",
      "echo '..................Firewall setup finished................'",
    ]
  }
}
