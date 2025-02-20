import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import SparkSession
from pyspark.sql.types import *
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',  
    'raw_zone_bucket_name',
    'object_key',
    'source_database_name',
    'source_table_name',
    'source_file_name',
    'glue_database_name',
    'clean_zone_bucket_name',
    'catalog_name'
    ])

rawZoneBucketName = args['raw_zone_bucket_name']
objectKey = args['object_key']
sourceDatabaseName = args['source_database_name']
sourceTableName = args['source_table_name']
sourceFileName = args['source_file_name']
glueDatabaseName = args['glue_database_name']
cleanZoneBucketName = args['clean_zone_bucket_name']
catalog_name = args['catalog_name']

# Define Iceberg Table Name and Storage Location
tableSuffix = f"{sourceDatabaseName}_{sourceTableName}"
glueDataCatalogTableName = tableSuffix.lower()
icebergTableName = f"iceberg_{tableSuffix}"
icebergS3Location = f"s3://{cleanZoneBucketName}/{icebergTableName}/"

# Initialize Spark Session with Iceberg Catalog configuration
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

# Read Source Table from Glue Data Catalog
InputDynamicFrameTable = glueContext.create_dynamic_frame.from_catalog(
    database=glueDatabaseName, 
    table_name=glueDataCatalogTableName, 
    transformation_ctx="InputDynamicFrameTable"
)

# Convert DynamicFrame to DataFrame
InputDynamicFrameTable_DF = InputDynamicFrameTable.toDF()

# Get Schema & Drop 'op' Column if Exists
schema = InputDynamicFrameTable_DF.schema
columns_to_keep = [field.name for field in schema if field.name != "op"]
final_DF = InputDynamicFrameTable_DF.select([col(c) for c in columns_to_keep])

# Convert `last_update_time` to Timestamp (If Exists)
if "last_update_time" in final_DF.columns:
    final_DF = final_DF.withColumn("last_update_time", col("last_update_time").cast("timestamp"))

# Register the DataFrame as a TempView
final_DF.createOrReplaceTempView("OutputDataFrameTable")

# Write the filtered data to an Iceberg table
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
