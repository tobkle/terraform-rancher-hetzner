resource "null_resource" "rancher_configuration" {

  depends_on = ["null_resource.rancher"]

  # Wait until dns for host is ready
  connection {
    type = "ssh"
    host = "${format(var.hostname_format, 1)}.${var.domain}"
    user = "${var.user}"
    private_key = "${file("~/.ssh/${var.ssh_key_name}")}"
  }

  provisioner "remote-exec" {
    inline = [

      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "echo 'Setting up: https://${format(var.hostname_format, 1)}.${var.domain}'",

      # Waiting, giving the server sum time
      "echo 'Sleeping for 60 seconds, giving the server time to startup...'",
      "sleep 60",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      # Wait for rancher-nginx server response
      "while ! curl -s --insecure https://${format(var.hostname_format, 1)}.${var.domain}/ping; do sleep 5 && echo 'Still sleeping...'; done",

      # Login with initial default user "admin" and default password "admin"
      "LOGINRESPONSE=`curl -s 'https://${format(var.hostname_format, 1)}.${var.domain}/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{\"username\":\"admin\",\"password\":\"admin\"}' --insecure`",

      # If the server isn't ready yet, we will receive a HTML response with e.g. Gateway, redo this request every 5s until we get a good answer in json
      # "while [ $LOGINRESPONSE =~ \"Gateway\" ] ; do sleep 5 && LOGINRESPONSE=`curl -s 'https://${format(var.hostname_format, 1)}.${var.domain}/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{\"username\":\"admin\",\"password\":\"admin\"}' --insecure`; done",
      "echo LOGINRESPONSE=$LOGINRESPONSE",

      # Get the Bearer Token
      "LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`",
      "echo LOGINTOKEN=$LOGINTOKEN",

      # Change the default password to my new password, which is stored in the rancher_password variable
      "PWCHANGE=`curl -s 'https://${format(var.hostname_format, 1)}.${var.domain}/v3/users?action=changepassword' -H 'content-type: application/json' -H \"Authorization: Bearer $LOGINTOKEN\" --data-binary '{\"currentPassword\":\"admin\",\"newPassword\":\"${var.rancher_password}\"}' --insecure`",
      "echo PWCHANGE=$PWCHANGE",

      # Create API key
      "APIRESPONSE=`curl -s 'https://${format(var.hostname_format, 1)}.${var.domain}/v3/token' -H 'content-type: application/json' -H \"Authorization: Bearer $LOGINTOKEN\" --data-binary '{\"type\":\"token\",\"description\":\"automation\"}' --insecure`",
      "echo APIRESPONSE=$APIRESPONSE",

      # Extract and store token
      "APITOKEN=`echo $APIRESPONSE | jq -r .token`",
      "echo APITOKEN=$APITOKEN",

      # Create cluster
      "CLUSTERRESPONSE=`curl -s 'https://${format(var.hostname_format, 1)}.${var.domain}/v3/cluster' -H 'content-type: application/json' -H \"Authorization: Bearer $LOGINTOKEN\" --data-binary '{\"type\":\"cluster\",\"nodes\":[],\"rancherKubernetesEngineConfig\":{\"ignoreDockerVersion\":true},\"name\":\"${var.rancher_cluster}\"}' --insecure`",
      "echo CLUSTERRESPONSE=$CLUSTERRESPONSE",

      # Extract clusterid to use for generating the docker run command
      "CLUSTERID=`echo $CLUSTERRESPONSE | jq -r .id`",
      "echo CLUSTERID=$CLUSTERID",

      # Generate docker run
      "AGENTIMAGE=`curl -s -H \"Authorization: Bearer $LOGINTOKEN\" https://${format(var.hostname_format, 1)}.${var.domain}/v3/settings/agent-image --insecure | jq -r .value`",
      "echo AGENTIMAGE=$AGENTIMAGE",

      "ROLEFLAGS='--etcd --controlplane --worker'",
      "echo ROLEFLAGS=$ROLEFLAGS",

      "RANCHERSERVER=\"https://${format(var.hostname_format, 1)}.${var.domain}\"",
      "echo RANCHERSERVER=$RANCHERSERVER",

      # Generate token (clusterRegistrationToken)
      "AGENTTOKEN=`curl -s 'https://${format(var.hostname_format, 1)}.${var.domain}/v3/clusterregistrationtoken' -H 'content-type: application/json' -H \"Authorization: Bearer $LOGINTOKEN\" --data-binary '{\"type\":\"clusterRegistrationToken\",\"clusterId\":\"'$CLUSTERID'\"}' --insecure | jq -r .token`",
      "echo AGENTTOKEN=$AGENTTOKEN",

      # Retrieve CA certificate and generate checksum
      "CACHECKSUM=`curl -s -H \"Authorization: Bearer $LOGINTOKEN\" https://${format(var.hostname_format, 1)}.${var.domain}}/v3/settings/cacerts --insecure | jq -r .value | sha256sum | awk '{ print $1 }'`",
      "echo CACHECKSUM=$CACHECKSUM",

      # Assemble the docker run command
      "AGENTCOMMAND=\"docker run -d --restart=unless-stopped -v /var/run/docker.sock:/var/run/docker.sock --net=host $AGENTIMAGE $ROLEFLAGS --server $RANCHERSERVER --token $AGENTTOKEN --ca-checksum $CACHECKSUM\"",
      "echo 'To connect your worker nodes with the Rancher Master node, therefore run the following command in the worker nodes shell: \n\n' $AGENTCOMMAND > /tmp/rancher_node.txt" ,

      # Send it by email
      "sudo /usr/sbin/sendmail ${var.email} < /tmp/rancher_node.txt",
    ]
  }
}

