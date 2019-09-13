##### SoftLayer/IBMCloud Access Credentials ######

variable "key_name" {
  description = "Name or reference of SSH key to provision IBM Cloud instances with"
  default = []
}

variable "deployment" {
   description = "Identifier prefix added to the host names."
   default = "ocp"
}

variable "domain" {
  description = "domain suffix added to all hostname FQDN"
  default = "ocp-cluster.com"
}

variable "os_image" {
  description = "IBM Cloud OS reference code to determine OS, version, word length"
  default = "ubuntu-16.04-amd64"
}

variable "vpc_region" {
  default   = "us-south"
}

variable "vpc_address_prefix" {
  description = "address prefixes for each zone in the VPC.  the VPC subnet CIDRs for each zone must be within the address prefix."
  default = [ "10.10.0.0/24", "10.11.0.0/24", "10.12.0.0/24" ]
}

variable "vpc_subnet_cidr" {
  default = [ "10.10.0.0/24", "10.11.0.0/24", "10.12.0.0/24" ]
}

##### OCP Instance details ######

variable "control" {
  type = "map"

  default = {
    profile           = "cc1-2x4"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB
    disk_profile      = "general-purpose"
    disk_iops         = "0"  // set if disk_profile is "custom"
  }
}

variable "master" {
  type = "map"

  default = {
    nodes             = "3"
    profile           = "cc1-8x16"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB

    disk_profile      = "general-purpose"
    disk_iops         = "0"  // set if disk_profile is "custom"

  }
}

variable "infra" {
  type = "map"

  default = {
    nodes       = "3"
    profile           = "bc1-4x16"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB
    disk_profile      = "general-purpose"
    disk_iops         = "0"  // set if disk_profile is "custom"

  }
}

variable "worker" {
  type = "map"

  default = {
    nodes       = "3"

    profile           = "bc1-4x16"

    disk_size         = "100" // GB, 25 or 100
    docker_vol_size   = "100" // GB
    disk_profile      = "general-purpose"
    disk_iops         = "0"  // set if disk_profile is "custom"

  }
}

variable "glusterfs" {
  type = "map"

  default = {
    nodes       = "3"

    profile           = "bc1-4x16"

    disk_size         = "100" // GB, 25 or 100
    docker_vol_size   = "100" // GB
    disk_profile      = "general-purpose"
    disk_iops         = "0"  // set if disk_profile is "custom"
    num_gluster_disks = "1"
    gluster_disk_size = "500"   // GB
  }
}

