variable "user" {
  description = "Hetzner user name on server"
  type = "string"
}

variable "ip_access" {
  description = "Hetzner IP address which is allowed to access server with ssh"
  type = "string"
}

variable "ssh_key_name" {
  description = "Hetzner SSH Key Name for Server Logins ~/.ssh/<HETZNER_SSH_KEY_NAME>.pub without path without file type ending"
  type = "string"
}

variable "count" {
  description = "Hetzner number of server to provision"
  type = "string"
}

variable "connections" {
  description = "ips"
  type = "list"
}

