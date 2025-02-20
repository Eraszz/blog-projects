application_name      = "iceberg-data-lakehouse"
password_database     = "supersecretpassword"
username_database     = "admin"
initial_database_name = "bookstoredb"
database_replication_structure = {
  bookstoredb = ["customer", "book", "sales"]
}
public_ip = "xxxxxxxxxxx/32"