# because LBs in IBM Cloud cannot have parallel operations performed on them, we added
# depends_on blocks to try to restrict the number of parallel operations happening on a single
# LB at a time.  We attempt to build LB first, then pool (serially), then listener (serially), 
# then attach pool members (serially).
# the resources are listed in the order they should be created.

resource "ibm_is_lb" "app" {
  name = "${var.deployment}-app-${random_id.clusterid.hex}"
  subnets = ["${ibm_is_subnet.ocp_subnet.*.id}"]
}

resource "ibm_is_lb_pool" "app-443" {
  lb = "${ibm_is_lb.app.id}"
  name = "${var.deployment}-app-443-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"
}

resource "ibm_is_lb_listener" "app-443" {
  lb = "${ibm_is_lb.app.id}"
  protocol = "tcp"
  port = "443"
  default_pool = "${element(split("/",ibm_is_lb_pool.app-443.id),1)}"
}

resource "ibm_is_lb_pool_member" "app-443" {
  count = "${var.infra["nodes"]}"
  lb = "${ibm_is_lb.app.id}"
  pool = "${element(split("/",ibm_is_lb_pool.app-443.id),1)}"
  port = "443"
  target_address = "${element(ibm_is_instance.ocp-infra.*.primary_network_interface.0.primary_ipv4_address, count.index)}"
}

resource "ibm_is_lb_pool" "app-80" {
  lb = "${ibm_is_lb.app.id}"
  name = "${var.deployment}-app-80-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.app-443",
    //"ibm_is_lb_pool.app-443"
  ]
}

resource "ibm_is_lb_listener" "app-80" {
  lb = "${ibm_is_lb.app.id}"
  protocol = "tcp"
  port = "80"
  default_pool = "${element(split("/",ibm_is_lb_pool.app-80.id),1)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.app-443",
    //"ibm_is_lb_pool.app-443"
  ]
}

resource "ibm_is_lb_pool_member" "app-80" {
  count = "${var.infra["nodes"]}"
  lb = "${ibm_is_lb.app.id}"
  pool = "${element(split("/",ibm_is_lb_pool.app-80.id),1)}"
  port = "80"
  target_address = "${element(ibm_is_instance.ocp-infra.*.primary_network_interface.0.primary_ipv4_address, count.index)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_pool_member.app-443",
    //"ibm_is_lb_pool.app-443",
    //"ibm_is_lb_listener.app-443"
  ]
}

resource "ibm_is_lb" "master" {
  name = "${var.deployment}-mastr-${random_id.clusterid.hex}"
  subnets = ["${ibm_is_subnet.ocp_subnet.*.id}"]
}

resource "ibm_is_lb_pool" "master-443" {
  lb = "${ibm_is_lb.master.id}"
  name = "${var.deployment}-master-443-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"
}

resource "ibm_is_lb_listener" "master-443" {
  protocol = "tcp"
  lb = "${ibm_is_lb.master.id}"
  port = "443"
  default_pool = "${element(split("/",ibm_is_lb_pool.master-443.id),1)}"
}

resource "ibm_is_lb_pool_member" "master-443" {
  count = "${var.master["nodes"]}"
  lb = "${ibm_is_lb.master.id}"
  pool = "${element(split("/",ibm_is_lb_pool.master-443.id),1)}"
  port = "443"
  target_address = "${element(ibm_is_instance.ocp-master.*.primary_network_interface.0.primary_ipv4_address, count.index)}"
}

