provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Owner       = var.owner
      Environment = var.env
      Project     = "CS2-NCA"
    }
  }
}
