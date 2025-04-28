terraform {
  backend "s3" {
    bucket = "litosh-cloud-resources-stor"  
    key    = "terraform/state/terraform.tfstate"  
    region = "eu-north-1"  
    encrypt = true  
  }
}
