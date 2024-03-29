provider "ibm" {
  generation = "1"
  ibmcloud_timeout = "60"
}

# Create a unique random clusterid for this cluster
resource "random_id" "clusterid" {
  byte_length = "4"
}