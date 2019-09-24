resource "ibm_is_security_group" "cluster_private" {
  name = "${var.deployment}-cluster-priv-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.ocp_vpc.id}"
}

resource "ibm_is_security_group_rule" "cluster_ingress_from_self" {
  direction = "inbound"
  remote = "${ibm_is_security_group.cluster_private.id}"
  group = "${ibm_is_security_group.cluster_private.id}"
}

resource "ibm_is_security_group_rule" "cluster_ingress_master" {
  direction = "inbound"
  remote = "${ibm_is_security_group.master_node.id}"
  group = "${ibm_is_security_group.cluster_private.id}"
}

resource "ibm_is_security_group_rule" "cluster_ingress_ssh_control" {
  direction = "inbound"
  remote = "${ibm_is_security_group.control_node.id}"
  group = "${ibm_is_security_group.cluster_private.id}"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "cluster_egress_all" {
  direction = "outbound"
  group = "${ibm_is_security_group.cluster_private.id}"
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group" "master_node" {
  name = "${var.deployment}-master-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.ocp_vpc.id}"
}

resource "ibm_is_security_group_rule" "master_ingress_ssh_control" {
  direction = "inbound"
  remote = "${ibm_is_security_group.control_node.id}"
  group = "${ibm_is_security_group.master_node.id}"
  tcp {
    port_min = 22
    port_max = 22
  }
}

# allow all traffic between master nodes
resource "ibm_is_security_group_rule" "master_ingress_self" {
  direction = "inbound"
  remote = "${ibm_is_security_group.master_node.id}"
  group = "${ibm_is_security_group.master_node.id}"
}

resource "ibm_is_security_group_rule" "master_ingress_sdn_cluster" {
  direction = "inbound"
  remote = "${ibm_is_security_group.cluster_private.id}"
  group = "${ibm_is_security_group.master_node.id}"
  udp {
    port_min = 4789
    port_max = 4789
  }
}

resource "ibm_is_security_group_rule" "master_ingress_dns_tcp_cluster" {
  direction = "inbound"
  remote = "${ibm_is_security_group.cluster_private.id}"
  group = "${ibm_is_security_group.master_node.id}"
  tcp {
    port_min = 8053
    port_max = 8053
  }
}

resource "ibm_is_security_group_rule" "master_ingress_dns_udp_cluster" {
  direction = "inbound"
  remote = "${ibm_is_security_group.cluster_private.id}"
  group = "${ibm_is_security_group.master_node.id}"
  udp {
    port_min = 8053
    port_max = 8053
  }
}

resource "ibm_is_security_group_rule" "master_ingress_api_cluster" {
  direction = "inbound"
  remote = "${ibm_is_security_group.cluster_private.id}"
  group = "${ibm_is_security_group.master_node.id}"
  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "master_egress_all" {
  direction = "outbound"
  group = "${ibm_is_security_group.master_node.id}"
  remote = "0.0.0.0/0"
}


# restrict incoming on ports to LBaaS private subnet
resource "ibm_is_security_group_rule" "master_ingress_port_443_all" {
  direction = "inbound"
  tcp {
    port_min = 443
    port_max = 443
  }
  group = "${ibm_is_security_group.master_node.id}"
  #remote = "${ibm_compute_vm_instance.ocp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "infra_inbound_port_80_all" {
  direction = "inbound"
  tcp {
    port_min = 80
    port_max = 80
  }
  group = "${ibm_is_security_group.infra_node.id}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "infra_inbound_port_443_all" {
  direction = "inbound"
  tcp {
    port_min = 443
    port_max = 443
  }
  group = "${ibm_is_security_group.infra_node.id}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group" "infra_node" {
  name = "${var.deployment}-infra-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.ocp_vpc.id}"
}

resource "ibm_is_security_group" "control_node" {
  name = "${var.deployment}-control-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.ocp_vpc.id}"
}

# TODO restrict to allowed CIDR
resource "ibm_is_security_group_rule" "control_ingress_ssh_all" {
  group = "${ibm_is_security_group.control_node.id}"
  direction = "inbound"
  remote = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "control_egress_all" {
  group = "${ibm_is_security_group.control_node.id}"
  remote = "0.0.0.0/0"
  direction = "outbound"
}
