# Setup Rancher 2.0 Cluster in Hetzner Cloud

Terraform script to setup a Rancher Cluster on the Provider Hetzner Cloud using the Domain Name Services (DNS) of Zeit.

[Rancher](https://rancher.com/)
[Letsencrypt](https://letsencrypt.org/)
[Kubernetes](https://kubernetes.io/)
[Docker](https://www.docker.com/)
[Hetzner](https://www.hetzner.de)
[Zeit](https://zeit.co/world)
[Terraform](https://www.terraform.io)

* Rancher 2.0 as a Kubernetes Cluster
* Letsencrypt SSL Certificate
* Kubernetes Cluster with 4 nodes
* Docker 1.13.1
* Ubuntu 16.04.04 LTS
* Firewall UFW
* Network Hardening
* Hetzner Cloud API
* Zeit DNS 
* Terraform Scripts

For Rancher 1.6 have a look into the backup file in the services/rancher-nginx folder.
For Nginx with Letsencrypt Setup have a look into the services/rancher-nginx folder.
You can use the other setup by changing the file main.tf script to the other services folder.

## Prerequisites

1. Setup [Go Language](https://golang.org/)
2. Setup [Terraform](https://www.terraform.io/downloads.html)
3. Setup [Hetzner Provider](https://github.com/hetznercloud/terraform-provider-hcloud)
4. Create Account on [Hetzner Cloud](https://www.hetzner.de/cloud)
5. Get API Token from Project [Hetzner Cloud Project](https://console.hetzner.cloud)
6. Create Account on [Zeit DNS](https://zeit.co/account)
7. Get API Token from Zeit
8. Git clone this repository
9. Cd into this repository
10. Create a new file **terraform.tfvars** with the following configuration entries:

```bash
letsencrypt_mode             = "--staging"
rancher_cluster              = "<your-new-name-for-the-rancher-cluster>"
rancher_password             = "<your-new-rancher-password>"
zeit_token                   = "<your-zeit-api-token>"
hetzner_token                = "<your-hetzner-api-token>"
hetzner_user_name            = "<your-new-ubuntu-server-user-name>"
hetzner_email                = "<your-email-address-for-sendmail>"
hetzner_ip_access            = "<your-local-ip-address-to-allow-ssh-through-ubuntu-server-firewall>"
hetzner_ssh_key_name         = "<your-private-key-file-name-in-folder~./ssh/>"
hetzner_domain               = "<your-domain-name-for-the-DNS-A-record>"
hetzner_server_count         = "<your-number-of-server-nodes-to-provision>"
hetzner_server_type          = "cx21"
hetzner_datacenter           = "nbg1-dc3"
hetzner_hostname_format      = "node-%03d"
hetzner_image                = "ubuntu-16.04"
hetzner_keep_disk            = "false"
hetzner_backup_window        = "02-06"
hetzner_iso_image            = ""
hetzner_rescue               = ""
hetzner_apt_install_packages = ["python-pip","vim","software-properties-common","ufw","ceph-common","nfs-common","jq","tmux"]
hetzner_apt_install_master   = ["nginx","python-certbot-nginx"]
```

**Caution:** With Rancher 2.0 it uses the --acme-domain directly with the live Letsencrypt server, which means the letsencrypt rate limits apply. So, if you run the script more than 5 times, you are locked out for some time. Read [Letsencrypt's Rate Limits](https://letsencrypt.org/docs/rate-limits/). You can use the staging environment with no rate limits only in the Rancher Nginx setup, which installs the Rancher Server without acme-domain certificate, but gets a Letsencrypt Staging Certificate within Nginx. If you are ready, clear the variable **letsencrypt_mode** from --staging to empty string, and it will run on the live server to obtain a real certificate.

Create the cluster with...
```bash
terraform init
terraform apply -auto-approve
```

After the finishing of the script, go to your URL https://node-001.<your-domain> and login with your new rancher password.

Delete the cluster with...
```bash
terraform destroy -auto-approve
```

Rancher Command Line Interface:
```bash
rancher login https://node-001.<your-domain> -t token-abcdef
```


