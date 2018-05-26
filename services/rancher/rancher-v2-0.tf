resource "null_resource" "rancher" {

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

      # Create Data Volume Container
      "sudo docker create --name rancher-data rancher/rancher:v2.0.0",

      # Creater Rancher v2.0.0 Container
      "sudo docker run -d --name rancher-server --restart=unless-stopped --volumes-from rancher-data -p 0.0.0.0:80:80 -p 0.0.0.0:443:443 rancher/rancher:v2.0.0 --acme-domain ${format(var.hostname_format, 1)}.${var.domain}",
    ]
  }
}