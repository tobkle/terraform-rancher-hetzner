resource "null_resource" "nginx" {

  connection {
    type = "ssh"
    host  = "${element(var.connections, 0)}"
    user = "${var.user}"
    private_key = "${file("~/.ssh/${var.ssh_key_name}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "sudo apt-get install -y ${join(" ", var.apt_install_master)}",
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "[ -d /var/www/html ] || sudo mkdir -p /var/www/html",
    ]
  }
}