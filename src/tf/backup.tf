locals {
  backup_bucket_name = "sgfdevs-vm-workloads-backups"
}

resource "b2_bucket" "backups" {
  bucket_name = local.backup_bucket_name
  bucket_type = "allPrivate"
}
