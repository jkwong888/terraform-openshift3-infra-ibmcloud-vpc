# Create a SSH key for SSH communication from terraform to VMs

data "ibm_is_ssh_key" "public_key" {
  count = "${length(var.key_name)}"
  name = "${element(var.key_name, count.index)}"
}

