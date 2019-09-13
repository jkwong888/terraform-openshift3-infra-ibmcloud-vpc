data "ibm_is_image" "osimage" {
  name = "${var.os_image}"
}

data "ibm_is_instance_profile" "ocp-control-profile" {
  name = "${var.control["profile"]}"
}

data "ibm_is_instance_profile" "ocp-master-profile" {
  name = "${var.master["profile"]}"
}

data "ibm_is_instance_profile" "ocp-infra-profile" {
  name = "${var.infra["profile"]}"
}

data "ibm_is_instance_profile" "ocp-worker-profile" {
  name = "${var.worker["profile"]}"
}

data "ibm_is_instance_profile" "ocp-glusterfs-profile" {
  name = "${var.glusterfs["profile"]}"
}

resource "ibm_is_floating_ip" "ocp-control-pub" {
  name 	 = "${var.deployment}-control-${random_id.clusterid.hex}-pubip"
  target = "${ibm_is_instance.ocp-control.primary_network_interface.0.id}"
}

##############################################
## Provision control node
##############################################

resource "ibm_is_instance" "ocp-control" {
  name = "${var.deployment}-control-${random_id.clusterid.hex}"

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, 0)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id, list(ibm_is_ssh_key.installkey.id))}"]
  profile = "${data.ibm_is_instance_profile.ocp-control-profile.name}"

  primary_network_interface = {
    subnet = "${element(ibm_is_subnet.ocp_subnet.*.id, 0)}"
    security_groups = ["${list(ibm_is_security_group.control_node.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"

  user_data = <<EOF
#cloud-config
users:
- default
- name: ocpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh_import_id: ocpdeploy
  ssh_authorized_keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /home/ocpdeploy/.ssh/id_rsa
  permissions: '0600'
  content: ${base64encode(tls_private_key.installkey.private_key_pem)}
  encoding: b64
  owner: ocpdeploy:ocpdeploy
- path: /home/ocpdeploy/.ssh/id_rsa.pub
  permissions: '0644'
  content: ${base64encode(tls_private_key.installkey.public_key_openssh)}
  encoding: b64
  owner: ocpdeploy:ocpdeploy
manage_etc_hosts: false
manage_resolv_conf: false
runcmd:
- chown -R ocpdeploy:ocpdeploy /home/ocpdeploy/.ssh
EOF
}

resource "ibm_is_volume" "ocp-master-docker-vol" {
  lifecycle {
    ignore_changes = [
      "iops"
    ]
  }

  count    = "${var.master["nodes"]}"
  name     = "${format("%s-master%02d-docker-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${var.master["disk_profile"]}"
  iops     = "${var.master["disk_iops"]}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${var.master["docker_vol_size"]}"
}

resource "ibm_is_instance" "ocp-master" {
  count = "${var.master["nodes"]}"
  name  = "${format("%s-master%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  depends_on = [
    "ibm_is_security_group_rule.control_ingress_ssh_all",
    "ibm_is_security_group_rule.control_egress_all",
    "ibm_is_security_group_rule.master_ingress_ssh_control",
    "ibm_is_security_group_rule.master_egress_all"
  ]

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id, list(ibm_is_ssh_key.installkey.id))}"]
  profile = "${data.ibm_is_instance_profile.ocp-master-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.ocp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.master_node.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.ocp-master-docker-vol.*.id, count.index)}"
  ]

  user_data = <<EOF
#cloud-config
manage_etc_hosts: false
manage_resolv_conf: false
users:
- default
- name: ocpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh_import_id: ocpdeploy
  ssh_authorized_keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /etc/sysconfig/docker-storage-setup
  permissions: '0600'
  content: |
    STORAGE_DRIVER=overlay2
    DEVS=/dev/xvdc
    CONTAINER_ROOT_LV_NAME=dockerlv
    CONTAINER_ROOT_LV_SIZE=100%FREE
    CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
    VG=dockervg
EOF
}

resource "ibm_is_volume" "ocp-infra-docker-vol" {
  lifecycle {
    ignore_changes = [
      "iops"
    ]
  }

  count    = "${var.infra["nodes"]}"
  name     = "${format("%s-infra%02d-docker-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${var.infra["disk_profile"]}"
  iops     = "${var.infra["disk_iops"]}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${var.infra["docker_vol_size"]}"
}

resource "ibm_is_instance" "ocp-infra" {
  count = "${var.infra["nodes"]}"
  depends_on = [
    "ibm_is_security_group_rule.control_ingress_ssh_all",
    "ibm_is_security_group_rule.control_egress_all",
    "ibm_is_security_group_rule.cluster_ingress_ssh_control",
    "ibm_is_security_group_rule.cluster_egress_all"
  ]

  name  = "${format("%s-infra%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id, list(ibm_is_ssh_key.installkey.id))}"]
  profile = "${data.ibm_is_instance_profile.ocp-infra-profile.name}"

  primary_network_interface = {
    subnet          = "${element(ibm_is_subnet.ocp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id, ibm_is_security_group.infra_node.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.ocp-infra-docker-vol.*.id, count.index)}"
  ]

  user_data = <<EOF
#cloud-config
users:
- default
- name: ocpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh_import_id: ocpdeploy
  ssh_authorized_keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /etc/sysconfig/docker-storage-setup
  permissions: '0600'
  content: |
    STORAGE_DRIVER=overlay2
    DEVS=/dev/xvdc
    CONTAINER_ROOT_LV_NAME=dockerlv
    CONTAINER_ROOT_LV_SIZE=100%FREE
    CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
    VG=dockervg
EOF
}

resource "ibm_is_volume" "ocp-worker-docker-vol" {
  lifecycle {
    ignore_changes = [
      "iops"
    ]
  }

  count    = "${var.worker["nodes"]}"
  name     = "${format("%s-worker%02d-docker-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${var.worker["disk_profile"]}"
  iops     = "${var.worker["disk_iops"]}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${var.worker["docker_vol_size"]}"
}

resource "ibm_is_instance" "ocp-worker" {
  count = "${var.worker["nodes"]}"
  depends_on = [
    "ibm_is_security_group_rule.control_ingress_ssh_all",
    "ibm_is_security_group_rule.control_egress_all",
    "ibm_is_security_group_rule.cluster_ingress_ssh_control",
    "ibm_is_security_group_rule.cluster_egress_all"
  ]

  name  = "${format("%s-worker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id, list(ibm_is_ssh_key.installkey.id))}"]
  profile = "${data.ibm_is_instance_profile.ocp-worker-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.ocp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.ocp-worker-docker-vol.*.id, count.index)}"
  ]

  user_data = <<EOF
#cloud-config
users:
- default
- name: ocpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  home: /home/ocpdeploy
  shell: /bin/bash
  ssh_import_id: ocpdeploy
  ssh_authorized_keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /etc/sysconfig/docker-storage-setup
  permissions: '0600'
  content: |
    STORAGE_DRIVER=overlay2
    DEVS=/dev/xvdc
    CONTAINER_ROOT_LV_NAME=dockerlv
    CONTAINER_ROOT_LV_SIZE=100%FREE
    CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
    VG=dockervg
EOF
}

resource "ibm_is_volume" "ocp-glusterfs-docker-vol" {
  lifecycle {
    ignore_changes = [
      "iops"
    ]
  }

  count    = "${var.glusterfs["nodes"]}"
  name     = "${format("%s-glusterfs%02d-docker-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${var.glusterfs["disk_profile"]}"
  iops     = "${var.glusterfs["disk_iops"]}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${var.glusterfs["docker_vol_size"]}"
}

resource "ibm_is_volume" "ocp-glusterfs-block-vol" {
  lifecycle {
    ignore_changes = [
      "iops"
    ]
  }

  count    = "${var.glusterfs["nodes"] * var.glusterfs["num_gluster_disks"]}"
  name     = "${format("%s-glusterfs%02d-block-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${var.glusterfs["disk_profile"]}"
  iops     = "${var.glusterfs["disk_iops"]}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${var.glusterfs["gluster_disk_size"]}"
}

resource "ibm_is_instance" "ocp-glusterfs" {
  count = "${var.glusterfs["nodes"]}"
  depends_on = [
    "ibm_is_security_group_rule.control_ingress_ssh_all",
    "ibm_is_security_group_rule.control_egress_all",
    "ibm_is_security_group_rule.cluster_ingress_ssh_control",
    "ibm_is_security_group_rule.cluster_egress_all"
  ]

  name  = "${format("%s-glusterfs%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id, list(ibm_is_ssh_key.installkey.id))}"]
  profile = "${data.ibm_is_instance_profile.ocp-glusterfs-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.ocp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.ocp-glusterfs-docker-vol.*.id, count.index)}",
    "${element(ibm_is_volume.ocp-glusterfs-block-vol.*.id, count.index + (count.index * var.glusterfs["nodes"]))}"
  ]

  user_data = <<EOF
#cloud-config
users:
- default
- name: ocpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh_import_id: ocpdeploy
  ssh_authorized_keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /etc/sysconfig/docker-storage-setup
  permissions: '0600'
  content: |
    STORAGE_DRIVER=overlay2
    DEVS=/dev/xvdc
    CONTAINER_ROOT_LV_NAME=dockerlv
    CONTAINER_ROOT_LV_SIZE=100%FREE
    CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
    VG=dockervg
EOF
}

