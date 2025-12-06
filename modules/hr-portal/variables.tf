variable "environment"   { 
    type = string 
    }
variable "db_host" { 
    type = string
    }
variable "db_name" { 
    type = string 
    }
variable "db_user" { 
    type = string 
    }
variable "db_password" { 
    type = string
    sensitive = true 
    }
variable "iam_instance_profile" { 
    type = string 
    }