import sys
import boto3
from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from awsglue.context import GlueContext
from awsglue.job import Job

# Parse input arguments from AWS Glue job
args = getResolvedOptions(sys.argv, [
    'JOB_NAME', 'raw_zone_bucket_name', 'object_key', 'source_database_name',
    'source_table_name', 'source_file_name', 'glue_database_name', 'clean_zone_bucket_name', 'catalog_name'
])

# Assign arguments to variables
rawZoneBucketName = args['raw_zone_bucket_name']
objectKey = args['object_key']
sourceDatabaseName = args['source_database_name']
sourceTableName = args['source_table_name']
sourceFileName = args['source_file_name']
glueDatabaseName = args['glue_database_name']
cleanZoneBucketName = args['clean_zone_bucket_name']
catalog_name = args['catalog_name']

# Define Iceberg table name and storage location
tableSuffix = f"{sourceDatabaseName}_{sourceTableName}"
icebergTableName = f"iceberg_{tableSuffix}"
icebergS3Location = f"s3://{cleanZoneBucketName}/{icebergTableName}/"

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

# Read CSV file from S3 into a Spark DataFrame
csv_path = f"s3://{rawZoneBucketName}/{objectKey}"
input_df = spark.read.option("header", True).option("inferSchema", True).csv(csv_path)

# Ensure 'Op' column exists
if "Op" not in input_df.columns:
    raise ValueError("ERROR: The 'Op' column is missing. It is required for processing.")

# Extract primary key (assumed to be the first column after 'Op')
primary_key_column = input_df.columns[1]

# Retrieve the existing schema from Iceberg
existing_schema_df = spark.sql(f"DESCRIBE {catalog_name}.{glueDatabaseName}.{icebergTableName}")

# Filter out invalid rows (empty or comments)
existing_schema_df_clean = existing_schema_df.filter(
    (existing_schema_df["col_name"] != "") & 
    (~existing_schema_df["col_name"].startswith("#")) &
    (existing_schema_df["data_type"] != "")
)

# Get valid column names and types
existing_columns = set(existing_schema_df_clean.select("col_name").rdd.flatMap(lambda x: x).collect())
existing_schema_dict = dict(existing_schema_df_clean.select("col_name", "data_type").rdd.map(lambda row: (row[0], row[1])).collect())

# Identify new columns that are in CSV but not in Iceberg
csv_schema = dict(input_df.dtypes)  # {col_name: data_type}
new_columns = {col: csv_schema[col] for col in csv_schema if col not in existing_columns and col != "Op"}

# Initialize merged schema dictionary
merged_schema_dict = existing_schema_dict.copy()
merged_columns = list(existing_columns)

# Dynamically add new columns to Iceberg if necessary
for new_col, data_type in new_columns.items():
    spark.sql(f"ALTER TABLE {catalog_name}.{glueDatabaseName}.{icebergTableName} ADD COLUMN {new_col} {data_type.upper()}")
    
    # Update the schema dictionary
    merged_schema_dict[new_col] = data_type.upper()
    merged_columns.append(new_col)

# Process each row sequentially
for row in input_df.collect():

    op_value = row['Op']
    # Remove the 'Op' field from the row (since it's no longer needed for SQL queries)
    row_data = {col: row[col] for col in row.asDict() if col != 'Op'}

    # Convert row dictionary to a single-row Spark DataFrame
    row_df = spark.createDataFrame([row_data])

    # Cast columns to match Iceberg schema
    for column_name, data_type in merged_schema_dict.items():
        if column_name in row_df.columns:
            row_df = row_df.withColumn(column_name, col(column_name).cast(data_type))

    # Create temporary table for this row
    row_df.createOrReplaceTempView("single_row_table")

    # Dynamically generate INSERT column lists
    insert_columns = merged_columns
    
    insert_column_values = ""
    update_table_column_list = ""
    for column in insert_columns:
        
        if column in row_df.columns:
            update_table_column_list+="""target.{0}=source.{0},""".format(column)
            
        insert_column_values += """source.{0},""".format(column) if column in row_df.columns else "NULL,"
    
    merge_query = ""

    if op_value == 'D':
        merge_query = """
            MERGE INTO glue_catalog.{0}.{1} target
            USING single_row_table source
            ON {2}
            WHEN MATCHED 
            THEN DELETE""".format(
                glueDatabaseName.lower(),  # Database name in lowercase
                icebergTableName.lower(),  # Iceberg table name in lowercase
                primary_key_column,  # Condition for matching
                update_table_column_list.rstrip(","),  # Update columns
                ",".join(insert_columns),  # Insert column names
                insert_column_values.rstrip(",")  # Insert column values
            )
        
    elif op_value in ['I', 'U']:    
        merge_query = """
            MERGE INTO glue_catalog.{0}.{1} target
            USING single_row_table source
            ON target.{2} = source.{2}
            WHEN MATCHED 
            THEN UPDATE SET {3} 
            WHEN NOT MATCHED THEN INSERT ({4}) VALUES ({5})""".format(
            glueDatabaseName.lower(),  # Database name in lowercase
            icebergTableName.lower(),  # Iceberg table name in lowercase
            primary_key_column,  # Condition for matching
            update_table_column_list.rstrip(","),  # Update columns
            ",".join(insert_columns),  # Insert column names
            insert_column_values.rstrip(",")  # Insert column values
        )

    spark.sql(merge_query)
    job.commit()
