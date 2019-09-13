# Create a SSH key for SSH communication from terraform to VMs
resource "tls_private_key" "installkey" {
  algorithm   = "RSA"
}

data "ibm_is_ssh_key" "public_key" {
  count = "${length(var.key_name)}"
  name = "${element(var.key_name, count.index)}"
}

resource "ibm_is_ssh_key" "installkey" {
  name = "${format("icp-%s", random_id.clusterid.hex)}"
  public_key = "${tls_private_key.installkey.public_key_openssh}"
}

