data "ibm_is_image" "osimage" {
  name = "${var.os_image}"
}

data "ibm_is_instance_profile" "ocp-control-profile" {
  name = "${lookup(var.control, "profile", "cc1-2x4")}"
}

data "ibm_is_instance_profile" "ocp-master-profile" {
  name = "${lookup(var.master, "profile", "bc1-8x32")}"
}

data "ibm_is_instance_profile" "ocp-infra-profile" {
  name = "${lookup(var.infra, "profile", "bc1-8x32")}"
}

data "ibm_is_instance_profile" "ocp-worker-profile" {
  name = "${lookup(var.worker, "profile", "bc1-4x16")}"
}

data "ibm_is_instance_profile" "ocp-glusterfs-profile" {
  name = "${lookup(var.glusterfs, "profile", "bc1-4x16")}"
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

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id)}"]
  profile = "${data.ibm_is_instance_profile.ocp-control-profile.name}"

  primary_network_interface = {
    subnet = "${element(ibm_is_subnet.ocp_subnet.*.id, 0)}"
    security_groups = ["${list(ibm_is_security_group.control_node.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"

  user_data = <<EOF
#cloud-config
package_upgrade: true
users:
- default
- name: ${var.ssh_user}
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh_import_id: ${var.ssh_user}
  ssh_authorized_keys:
  - ${var.ssh_public_key}
preserve_hostname: false
fqdn: ${format("%s-control-%s.%s", var.deployment, random_id.clusterid.hex, var.domain)}
hostname: ${format("%s-control-%s", var.deployment, random_id.clusterid.hex)}
write_files:
- path: /home/${var.ssh_user}/.ssh/id_rsa
  permissions: '0600'
  content: ${base64encode(var.ssh_private_key)}
  encoding: b64
  owner: ${var.ssh_user}:${var.ssh_user}
- path: /home/${var.ssh_user}/.ssh/id_rsa.pub
  permissions: '0644'
  content: ${base64encode(var.ssh_public_key)}
  encoding: b64
  owner: ${var.ssh_user}:${var.ssh_user}
manage_etc_hosts: false
manage_resolv_conf: false
runcmd:
- chown -R ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}
EOF
}

resource "ibm_is_volume" "ocp-master-docker-vol" {
  lifecycle {
    ignore_changes = [
      "iops"
    ]
  }

  count    = "${lookup(var.master, "nodes", 3)}"
  name     = "${format("%s-master%02d-docker-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${lookup(var.master, "disk_profile", "general-purpose")}"
  iops     = "${lookup(var.master, "disk_iops", 0)}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${lookup(var.master, "docker_vol_size", 100)}"
}

resource "ibm_is_instance" "ocp-master" {
  count = "${lookup(var.master, "nodes", 3)}"
  name  = "${format("%s-master%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  depends_on = [
    "ibm_is_security_group_rule.control_ingress_ssh_all",
    "ibm_is_security_group_rule.control_egress_all",
    "ibm_is_security_group_rule.master_ingress_ssh_control",
    "ibm_is_security_group_rule.master_egress_all"
  ]

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id)}"]
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
package_upgrade: true
manage_etc_hosts: false
manage_resolv_conf: false
users:
- default
- name: ${var.ssh_user}
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh_import_id: ${var.ssh_user}
  ssh_authorized_keys:
  - ${var.ssh_public_key}
preserve_hostname: false
fqdn: ${format("%s-master%02d-%s.%s", var.deployment, count.index + 1, random_id.clusterid.hex, var.domain)}
hostname: ${format("%s-master%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}
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

  count    = "${lookup(var.infra, "nodes", 3)}"
  name     = "${format("%s-infra%02d-docker-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${lookup(var.infra, "disk_profile", "general-purpose")}"
  iops     = "${lookup(var.infra, "disk_iops", 0)}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${lookup(var.infra, "docker_vol_size", 100)}"
}

resource "ibm_is_instance" "ocp-infra" {
  count = "${lookup(var.infra, "nodes", 3)}"
  depends_on = [
    "ibm_is_security_group_rule.control_ingress_ssh_all",
    "ibm_is_security_group_rule.control_egress_all",
    "ibm_is_security_group_rule.cluster_ingress_ssh_control",
    "ibm_is_security_group_rule.cluster_egress_all"
  ]

  name  = "${format("%s-infra%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id)}"]
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
package_upgrade: true
users:
- default
- name: ${var.ssh_user}
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh_import_id: ${var.ssh_user}
  ssh_authorized_keys:
  - ${var.ssh_public_key}
preserve_hostname: false
fqdn: ${format("%s-infra%02d-%s.%s", var.deployment, count.index + 1, random_id.clusterid.hex, var.domain)}
hostname: ${format("%s-infra%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}
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

  count    = "${lookup(var.worker, "nodes", 3)}"
  name     = "${format("%s-worker%02d-docker-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${lookup(var.worker, "disk_profile", "general-purpose")}"
  iops     = "${lookup(var.worker, "disk_iops", 0)}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${lookup(var.worker, "docker_vol_size", 100)}"

}

resource "ibm_is_instance" "ocp-worker" {
  count    = "${lookup(var.worker, "nodes", 3)}"
  depends_on = [
    "ibm_is_security_group_rule.control_ingress_ssh_all",
    "ibm_is_security_group_rule.control_egress_all",
    "ibm_is_security_group_rule.cluster_ingress_ssh_control",
    "ibm_is_security_group_rule.cluster_egress_all"
  ]

  name  = "${format("%s-worker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id)}"]
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
package_upgrade: true
users:
- default
- name: ${var.ssh_user}
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  home: /home/${var.ssh_user}
  shell: /bin/bash
  ssh_import_id: ${var.ssh_user}
  ssh_authorized_keys:
  - ${var.ssh_public_key}
preserve_hostname: false
fqdn: ${format("%s-worker%02d-%s.%s", var.deployment, count.index + 1, random_id.clusterid.hex, var.domain)}
hostname: ${format("%s-worker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}
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

  count    = "${lookup(var.glusterfs, "nodes", 3)}"
  name     = "${format("%s-glusterfs%02d-docker-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "${lookup(var.glusterfs, "disk_profile", "general-purpose")}"
  iops     = "${lookup(var.glusterfs, "disk_iops", 0)}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"
  capacity = "${lookup(var.glusterfs, "docker_vol_size", 100)}"
}

# disk list is ordered by node and block device, e.g.
# [node1block1,node1block2,node2block1,node2block2,node3block1,node3block2]
resource "ibm_is_volume" "ocp-glusterfs-block-vol" {
  lifecycle {
    ignore_changes = [
      "iops"
    ]
  }

  count    = "${lookup(var.glusterfs, "nodes", 3) * lookup(var.glusterfs, "num_gluster_disks", 1)}"
  name     = "${format("%s-glusterfs%02d-block%02d-%s", 
                       var.deployment, 
                       floor(count.index / lookup(var.glusterfs, "num_gluster_disks", 1)) + 1, 
                       count.index % lookup(var.glusterfs, "num_gluster_disks", 1) + 1, 
                       random_id.clusterid.hex)}"
  profile  = "${lookup(var.glusterfs, "disk_profile", "general-purpose")}"
  iops     = "${lookup(var.glusterfs, "disk_iops", 0)}"
  zone     = "${element(data.ibm_is_zone.ocp_zone.*.name, 
                        floor(count.index / lookup(var.glusterfs, "num_gluster_disks", 1)))}"
  capacity = "${lookup(var.glusterfs, "gluster_disk_size", 500)}"
}

resource "ibm_is_instance" "ocp-glusterfs" {
  count = "${lookup(var.glusterfs, "nodes", 3)}"
  depends_on = [
    "ibm_is_security_group_rule.control_ingress_ssh_all",
    "ibm_is_security_group_rule.control_egress_all",
    "ibm_is_security_group_rule.cluster_ingress_ssh_control",
    "ibm_is_security_group_rule.cluster_egress_all"
  ]

  name  = "${format("%s-glusterfs%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.ocp_vpc.id}"
  zone = "${element(data.ibm_is_zone.ocp_zone.*.name, count.index)}"

  keys = ["${concat(data.ibm_is_ssh_key.public_key.*.id)}"]
  profile = "${data.ibm_is_instance_profile.ocp-glusterfs-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.ocp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"

  # disk list is ordered by node and block device, e.g.
  # [node1block1,node1block2,node2block1,node2block2,node3block1,node3block2]
  volumes = ["${concat(
    list(element(ibm_is_volume.ocp-glusterfs-docker-vol.*.id, count.index)),
    slice(ibm_is_volume.ocp-glusterfs-block-vol.*.id, 
          count.index * lookup(var.glusterfs, "num_gluster_disks", 1), 
          (count.index + 1) * lookup(var.glusterfs, "num_gluster_disks", 1))
    )}"
  ]

  user_data = <<EOF
#cloud-config
package_upgrade: true
users:
- default
- name: ${var.ssh_user}
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh_import_id: ${var.ssh_user}
  ssh_authorized_keys:
  - ${var.ssh_public_key}
preserve_hostname: false
fqdn: ${format("%s-glusterfs%02d-%s.%s", var.deployment, count.index + 1, random_id.clusterid.hex, var.domain)}
hostname: ${format("%s-glusterfs%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}
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

