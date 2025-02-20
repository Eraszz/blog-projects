import sys
import boto3
from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col


# Parse input arguments from AWS Glue job
args = getResolvedOptions(sys.argv, [
    'JOB_NAME', 
    'sales_table_name', 
    'customer_table_name', 
    'book_table_name', 
    'glue_database_name', 
    'refined_zone_bucket_name', 
    'catalog_name', 
    'iceberge_consolidated_table_name'
])

# Assign arguments to variables
salesTableName = args['sales_table_name']
customerTableName = args['customer_table_name']
bookTableName = args['book_table_name']
glueDatabaseName = args['glue_database_name']
refinedZoneBucketName = args['refined_zone_bucket_name']
catalog_name = args['catalog_name']

icebergTableName = args['iceberge_consolidated_table_name']
icebergS3Location = f"s3://{refinedZoneBucketName}/{icebergTableName}/"

# Initialize Spark Session with Iceberg configurations

spark = SparkSession.builder \
    .config(f"spark.sql.catalog.{catalog_name}", "org.apache.iceberg.spark.SparkCatalog") \
    .config(f"spark.sql.catalog.{catalog_name}.warehouse", icebergS3Location) \
    .config(f"spark.sql.catalog.{catalog_name}.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog") \
    .config(f"spark.sql.catalog.{catalog_name}.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
    .config(f"spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .getOrCreate()

# Initialize Spark & Glue Context
sc = spark.sparkContext
glueContext = GlueContext(sc)
job = Job(glueContext)
job.init(args['JOB_NAME'], args)


# Load Sales, Customer, and Book tables as DataFrames
sales_df = spark.read.format("iceberg") \
    .load(f"{catalog_name}.{glueDatabaseName}.{salesTableName}")

customer_df = spark.read.format("iceberg") \
    .load(f"{catalog_name}.{glueDatabaseName}.{customerTableName}")

book_df = spark.read.format("iceberg") \
    .load(f"{catalog_name}.{glueDatabaseName}.{bookTableName}")

# Rename columns in sales_df and customer_df before performing the join
sales_df_renamed = sales_df.withColumnRenamed("last_update_time", "sale_last_update_time")

customer_df_renamed = customer_df.withColumnRenamed("customer_id", "customer_customer_id") \
                                 .withColumnRenamed("last_update_time", "customer_last_update_time")

book_df_renamed = book_df.withColumnRenamed("book_id", "book_book_id") \
                                 .withColumnRenamed("last_update_time", "book_last_update_time")

# Perform the join with the renamed columns
sales_customer_join_df = sales_df_renamed.join(
    customer_df_renamed,
    sales_df_renamed["customer_id"] == customer_df_renamed["customer_customer_id"],
    "left"
)


# Perform Inner Join between Sales and Book on the common key
sales_complete_join_df = sales_customer_join_df.join(
    book_df_renamed,
    sales_df_renamed["book_id"] == book_df_renamed["book_book_id"],
    "left"
)

# Drop unneeded join columns
sales_complete_join_df = sales_complete_join_df.drop("book_book_id").drop("customer_customer_id")

# Register the DataFrame as a TempView
sales_complete_join_df.createOrReplaceTempView("OutputDataFrameTable")

# Step 6: Write the filtered data to an Iceberg table
create_table_query = f"""
    CREATE OR REPLACE TABLE {catalog_name}.`{glueDatabaseName}`.{icebergTableName}
    USING iceberg
    TBLPROPERTIES ("format-version"="2")
    AS SELECT * FROM OutputDataFrameTable;
    """

# Run the Spark SQL query
spark.sql(create_table_query)

#Update Table property to accept Schema Changes
spark.sql(f"""ALTER TABLE {catalog_name}.`{glueDatabaseName}`.{icebergTableName} SET TBLPROPERTIES (
                'write.spark.accept-any-schema'='true'
            )""")

job.commit()