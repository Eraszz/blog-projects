user_email_address    = "xxxxxxxxxx"
user_first_name       = "xxxxxxxxxx"
user_last_name        = "xxxxxxxxxx"

application_name      = "appstream-db-manager"
password_database     = "supersecretpassword"
username_database     = "admin"
initial_database_name = "bookstoredb"
appstream_fleet_name  = "dbeaver"

vpc_cidr_block = "172.16.0.0/16"

public_subnets = {
  subnet_1 = {
    cidr_block        = "172.16.0.0/24"
    availability_zone = "eu-central-1a"
  }
  subnet_2 = {
    cidr_block        = "172.16.1.0/24"
    availability_zone = "eu-central-1b"
  }
}

private_subnets = {
  subnet_1 = {
    cidr_block        = "172.16.2.0/24"
    availability_zone = "eu-central-1a"
  }
  subnet_2 = {
    cidr_block        = "172.16.3.0/24"
    availability_zone = "eu-central-1b"
  }
}