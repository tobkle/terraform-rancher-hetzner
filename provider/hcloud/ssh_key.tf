resource "hcloud_ssh_key" "ssh_key" {
  name = "${var.hetzner_ssh_key_name}"
  public_key = "${file("~/.ssh/${var.hetzner_ssh_key_name}.pub")}"
}