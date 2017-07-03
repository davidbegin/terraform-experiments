terragrunt = {
  lock = {
    backend = "dynamodb"

    config {
      state_file_id = "global/s3"
    }
  }

  remote_state {
    backend = "s3"

    config {
      encrypt = "true"
      bucket = "begins_first_terraform_state_bucket"
      key    = "global/s3/terraform.tfstate"
      region = "us-east-1"
    }
  }
}

  remote_state {
    backend = "s3"
    config {
      bucket     = "my-terraform-state"
      key        = "${path_relative_to_include()}/terraform.tfstate"
      region     = "us-east-1"
      encrypt    = true
      lock_table = "my-lock-table"
    }
  }
