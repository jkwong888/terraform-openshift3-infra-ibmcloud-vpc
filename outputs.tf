# #################################################
# # Output Bastion Node
# #################################################
#
output "bastion_public_ip" {
  value = "${ibm_is_floating_ip.ocp-control-pub.address}"
}

output "bastion_private_ip" {
  value = "${ibm_is_instance.ocp-control.primary_network_interface.0.primary_ipv4_address}"
}

output "bastion_hostname" {
  value = "${ibm_is_instance.ocp-control.name}"
}


#################################################
# Output Master Node
#################################################
output "master_private_ip" {
  value = "${ibm_is_instance.ocp-master.*.primary_network_interface.0.primary_ipv4_address}"
}

output "master_hostname" {
  value = "${ibm_is_instance.ocp-master.*.name}"
}


#################################################
# Output Infra Node
#################################################
output "infra_private_ip" {
  value = "${ibm_is_instance.ocp-infra.*.primary_network_interface.0.primary_ipv4_address}"
}

output "infra_hostname" {
  value = "${ibm_is_instance.ocp-infra.*.name}"
}


#################################################
# Output App Node
#################################################
output "worker_private_ip" {
  value = "${ibm_is_instance.ocp-worker.*.primary_network_interface.0.primary_ipv4_address}"
}

output "worker_hostname" {
  value = "${ibm_is_instance.ocp-worker.*.name}"
}


#################################################
# Output Storage Node
#################################################
output "storage_private_ip" {
  value = "${ibm_is_instance.ocp-glusterfs.*.primary_network_interface.0.primary_ipv4_address}"
}

output "storage_hostname" {
  value = "${ibm_is_instance.ocp-glusterfs.*.name}"
}

output "master_loadbalancer_hostname" {
  value = "${ibm_is_lb.master.hostname}"
}

output "app_loadblancer_hostname" {
  value = "${ibm_is_lb.app.hostname}"
}

