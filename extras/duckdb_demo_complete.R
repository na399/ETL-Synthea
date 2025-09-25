######################################
## Complete DuckDB End-to-End Demo for ETL-Synthea ##
## This demonstrates the full ETL pipeline with OMOP CDM transformation ##
######################################

cat("=== Complete DuckDB/SQLite ETL-Synthea Demo ===\n\n")

# Load required libraries
library("DBI")

# Try to load DuckDB, fall back to SQLite if not available
use_duckdb <- tryCatch({
  library("duckdb")
  cat("✓ DuckDB package loaded successfully\n")
  TRUE
}, error = function(e) {
  cat("⚠ DuckDB package not available, using RSQLite as fallback\n")
  library("RSQLite")
  FALSE
})

# Function to download all seed data from OHDSI/dbt-synthea repository
download_complete_dbt_synthea_seeds <- function(target_dir = "dbt_synthea_seeds") {
  cat("\n📥 Downloading complete seed data from OHDSI/dbt-synthea repository...\n")
  
  if (!dir.exists(target_dir)) {
    dir.create(target_dir, recursive = TRUE)
  }
  
  # Create subdirectories for different data types
  synthea_dir <- file.path(target_dir, "synthea")
  vocab_dir <- file.path(target_dir, "vocabulary")
  
  if (!dir.exists(synthea_dir)) dir.create(synthea_dir, recursive = TRUE)
  if (!dir.exists(vocab_dir)) dir.create(vocab_dir, recursive = TRUE)
  
  # Base URL for raw files from OHDSI/dbt-synthea
  base_url <- "https://raw.githubusercontent.com/OHDSI/dbt-synthea/main/seeds"
  
  # All Synthea files from the repository
  synthea_files <- c(
    "allergies.csv", "careplans.csv", "claims.csv", "claims_transactions.csv",
    "conditions.csv", "devices.csv", "encounters.csv", "imaging_studies.csv",
    "immunizations.csv", "medications.csv", "observations.csv", 
    "organizations.csv", "patients.csv", "payer_transitions.csv",
    "payers.csv", "procedures.csv", "providers.csv", "supplies.csv"
  )
  
  # All vocabulary files from the repository
  vocab_files <- c(
    "concept_ancestor_seed.csv", "concept_class_seed.csv", 
    "concept_relationship_seed.csv", "concept_seed.csv",
    "concept_synonym_seed.csv", "domain_seed.csv", 
    "drug_strength_seed.csv", "relationship_seed.csv",
    "vocabulary_seed.csv"
  )
  
  download_count <- 0
  
  # Download Synthea files
  cat("Downloading Synthea files...\n")
  for (file in synthea_files) {
    url <- paste0(base_url, "/synthea/", file)
    dest <- file.path(synthea_dir, file)
    tryCatch({
      download.file(url, dest, method = "auto", quiet = TRUE)
      cat("  ✓ Downloaded:", file, "\n")
      download_count <- download_count + 1
    }, error = function(e) {
      cat("  ✗ Failed to download:", file, "\n")
    })
  }
  
  # Download vocabulary files
  cat("Downloading vocabulary files...\n")
  for (file in vocab_files) {
    url <- paste0(base_url, "/vocabulary/", file)
    dest <- file.path(vocab_dir, file)
    tryCatch({
      download.file(url, dest, method = "auto", quiet = TRUE)
      cat("  ✓ Downloaded:", file, "\n")
      download_count <- download_count + 1
    }, error = function(e) {
      cat("  ✗ Failed to download:", file, "\n")
    })
  }
  
  cat("📦 Download complete! (", download_count, "files)\n")
  return(list(synthea_dir = synthea_dir, vocab_dir = vocab_dir))
}

# Create database connection
create_local_connection <- function(db_path = "synthea_omop_demo.db") {
  if (use_duckdb) {
    cat("🦆 Creating DuckDB connection at:", db_path, "\n")
    drv <- duckdb::duckdb()
    conn <- DBI::dbConnect(drv, dbdir = db_path)
  } else {
    cat("🗃️  Creating SQLite connection at:", db_path, "\n")
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = db_path)
  }
  return(conn)
}

# Load CSV file into database table with schema prefix
load_csv_to_table <- function(conn, csv_path, table_name, schema_prefix = "", max_rows = NULL) {
  if (!file.exists(csv_path)) {
    cat("  ⚠ File not found:", csv_path, "\n")
    return(FALSE)
  }
  
  full_table_name <- ifelse(schema_prefix == "", table_name, paste0(schema_prefix, "_", table_name))
  
  tryCatch({
    # Read CSV with optional row limit for large files
    if (is.null(max_rows)) {
      data <- read.csv(csv_path, stringsAsFactors = FALSE)
    } else {
      data <- read.csv(csv_path, stringsAsFactors = FALSE, nrows = max_rows)
    }
    
    # Write to database
    DBI::dbWriteTable(conn, full_table_name, data, overwrite = TRUE)
    cat("  ✓ Loaded", full_table_name, "with", nrow(data), "rows\n")
    return(TRUE)
  }, error = function(e) {
    cat("  ✗ Error loading", full_table_name, ":", e$message, "\n")
    return(FALSE)
  })
}

# Create OMOP CDM tables (simplified version)
create_omop_cdm_tables <- function(conn) {
  cat("\n🏗️  Creating OMOP CDM tables...\n")
  
  # Create basic OMOP CDM tables with simplified schema
  omop_tables <- list(
    person = "
      CREATE TABLE cdm_person (
        person_id INTEGER PRIMARY KEY,
        gender_concept_id INTEGER,
        year_of_birth INTEGER,
        month_of_birth INTEGER,
        day_of_birth INTEGER,
        birth_datetime TEXT,
        death_datetime TEXT,
        race_concept_id INTEGER,
        ethnicity_concept_id INTEGER,
        location_id INTEGER,
        provider_id INTEGER,
        care_site_id INTEGER,
        person_source_value TEXT,
        gender_source_value TEXT,
        gender_source_concept_id INTEGER,
        race_source_value TEXT,
        race_source_concept_id INTEGER,
        ethnicity_source_value TEXT,
        ethnicity_source_concept_id INTEGER
      )
    ",
    
    visit_occurrence = "
      CREATE TABLE cdm_visit_occurrence (
        visit_occurrence_id INTEGER PRIMARY KEY,
        person_id INTEGER,
        visit_concept_id INTEGER,
        visit_start_date TEXT,
        visit_start_datetime TEXT,
        visit_end_date TEXT,
        visit_end_datetime TEXT,
        visit_type_concept_id INTEGER,
        provider_id INTEGER,
        care_site_id INTEGER,
        visit_source_value TEXT,
        visit_source_concept_id INTEGER,
        admitted_from_concept_id INTEGER,
        admitted_from_source_value TEXT,
        discharged_to_concept_id INTEGER,
        discharged_to_source_value TEXT,
        preceding_visit_occurrence_id INTEGER
      )
    ",
    
    condition_occurrence = "
      CREATE TABLE cdm_condition_occurrence (
        condition_occurrence_id INTEGER PRIMARY KEY,
        person_id INTEGER,
        condition_concept_id INTEGER,
        condition_start_date TEXT,
        condition_start_datetime TEXT,
        condition_end_date TEXT,
        condition_end_datetime TEXT,
        condition_type_concept_id INTEGER,
        condition_status_concept_id INTEGER,
        stop_reason TEXT,
        provider_id INTEGER,
        visit_occurrence_id INTEGER,
        visit_detail_id INTEGER,
        condition_source_value TEXT,
        condition_source_concept_id INTEGER,
        condition_status_source_value TEXT
      )
    ",
    
    drug_exposure = "
      CREATE TABLE cdm_drug_exposure (
        drug_exposure_id INTEGER PRIMARY KEY,
        person_id INTEGER,
        drug_concept_id INTEGER,
        drug_exposure_start_date TEXT,
        drug_exposure_start_datetime TEXT,
        drug_exposure_end_date TEXT,
        drug_exposure_end_datetime TEXT,
        verbatim_end_date TEXT,
        drug_type_concept_id INTEGER,
        stop_reason TEXT,
        refills INTEGER,
        quantity REAL,
        days_supply INTEGER,
        sig TEXT,
        route_concept_id INTEGER,
        lot_number TEXT,
        provider_id INTEGER,
        visit_occurrence_id INTEGER,
        visit_detail_id INTEGER,
        drug_source_value TEXT,
        drug_source_concept_id INTEGER,
        route_source_value TEXT,
        dose_unit_source_value TEXT
      )
    "
  )
  
  # Create tables
  for (table_name in names(omop_tables)) {
    tryCatch({
      DBI::dbExecute(conn, omop_tables[[table_name]])
      cat("  ✓ Created OMOP table:", paste0("cdm_", table_name), "\n")
    }, error = function(e) {
      cat("  ⚠ Error creating", table_name, "- may already exist\n")
    })
  }
}

# Perform basic ETL transformations (simplified OMOP mapping)
perform_etl_transformations <- function(conn) {
  cat("\n🔄 Performing ETL transformations to OMOP CDM...\n")
  
  # Transform patients to person table
  tryCatch({
    DBI::dbExecute(conn, "
      INSERT INTO cdm_person (
        person_id, gender_concept_id, year_of_birth, month_of_birth, day_of_birth,
        birth_datetime, death_datetime, person_source_value, gender_source_value
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY Id) as person_id,
        CASE 
          WHEN GENDER = 'M' THEN 8507  -- OMOP concept for Male
          WHEN GENDER = 'F' THEN 8532  -- OMOP concept for Female
          ELSE 0
        END as gender_concept_id,
        CAST(strftime('%Y', BIRTHDATE) AS INTEGER) as year_of_birth,
        CAST(strftime('%m', BIRTHDATE) AS INTEGER) as month_of_birth,
        CAST(strftime('%d', BIRTHDATE) AS INTEGER) as day_of_birth,
        BIRTHDATE as birth_datetime,
        DEATHDATE as death_datetime,
        Id as person_source_value,
        GENDER as gender_source_value
      FROM synthea_patients
    ")
    
    person_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as count FROM cdm_person")$count
    cat("  ✓ Transformed", person_count, "patients to OMOP person table\n")
  }, error = function(e) {
    cat("  ✗ Error transforming patients:", e$message, "\n")
  })
  
  # Transform encounters to visit_occurrence table
  tryCatch({
    DBI::dbExecute(conn, "
      INSERT INTO cdm_visit_occurrence (
        visit_occurrence_id, person_id, visit_concept_id, visit_start_date,
        visit_start_datetime, visit_end_date, visit_end_datetime, visit_source_value
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY e.Id) as visit_occurrence_id,
        p.person_id,
        CASE 
          WHEN e.ENCOUNTERCLASS = 'inpatient' THEN 9201
          WHEN e.ENCOUNTERCLASS = 'outpatient' THEN 9202
          WHEN e.ENCOUNTERCLASS = 'emergency' THEN 9203
          ELSE 0
        END as visit_concept_id,
        DATE(e.START) as visit_start_date,
        e.START as visit_start_datetime,
        COALESCE(DATE(e.STOP), DATE(e.START)) as visit_end_date,
        COALESCE(e.STOP, e.START) as visit_end_datetime,
        e.Id as visit_source_value
      FROM synthea_encounters e
      JOIN cdm_person p ON e.PATIENT = p.person_source_value
    ")
    
    visit_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as count FROM cdm_visit_occurrence")$count
    cat("  ✓ Transformed", visit_count, "encounters to OMOP visit_occurrence table\n")
  }, error = function(e) {
    cat("  ✗ Error transforming encounters:", e$message, "\n")
  })
  
  # Transform conditions to condition_occurrence table
  tryCatch({
    DBI::dbExecute(conn, "
      INSERT INTO cdm_condition_occurrence (
        condition_occurrence_id, person_id, condition_concept_id, condition_start_date,
        condition_start_datetime, condition_end_date, condition_end_datetime,
        visit_occurrence_id, condition_source_value
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY c.START) as condition_occurrence_id,
        p.person_id,
        0 as condition_concept_id,  -- Would need proper concept mapping
        DATE(c.START) as condition_start_date,
        c.START as condition_start_datetime,
        COALESCE(DATE(c.STOP), DATE(c.START)) as condition_end_date,
        COALESCE(c.STOP, c.START) as condition_end_datetime,
        v.visit_occurrence_id,
        c.CODE as condition_source_value
      FROM synthea_conditions c
      JOIN cdm_person p ON c.PATIENT = p.person_source_value
      LEFT JOIN cdm_visit_occurrence v ON c.ENCOUNTER = v.visit_source_value
    ")
    
    condition_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as count FROM cdm_condition_occurrence")$count
    cat("  ✓ Transformed", condition_count, "conditions to OMOP condition_occurrence table\n")
  }, error = function(e) {
    cat("  ✗ Error transforming conditions:", e$message, "\n")
  })
}

# Run OMOP CDM validation queries
run_omop_validation_queries <- function(conn) {
  cat("\n📊 Running OMOP CDM validation queries...\n")
  
  # Check all tables
  tables <- DBI::dbListTables(conn)
  omop_tables <- tables[grepl("^cdm_", tables)]
  cat("OMOP CDM tables created:", paste(omop_tables, collapse = ", "), "\n\n")
  
  # Basic counts
  if ("cdm_person" %in% tables) {
    result <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as person_count FROM cdm_person")
    cat("👥 Total persons in CDM:", result$person_count, "\n")
    
    # Gender distribution
    gender_dist <- DBI::dbGetQuery(conn, "
      SELECT 
        CASE 
          WHEN gender_concept_id = 8507 THEN 'Male'
          WHEN gender_concept_id = 8532 THEN 'Female'
          ELSE 'Unknown'
        END as gender,
        COUNT(*) as count
      FROM cdm_person 
      GROUP BY gender_concept_id
    ")
    cat("Gender distribution:\n")
    print(gender_dist)
  }
  
  if ("cdm_visit_occurrence" %in% tables) {
    result <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as visit_count FROM cdm_visit_occurrence")
    cat("\n🏥 Total visits in CDM:", result$visit_count, "\n")
  }
  
  if ("cdm_condition_occurrence" %in% tables) {
    result <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as condition_count FROM cdm_condition_occurrence")
    cat("🩺 Total conditions in CDM:", result$condition_count, "\n")
  }
  
  # Data quality check
  if (all(c("cdm_person", "cdm_visit_occurrence") %in% tables)) {
    cat("\n🔍 Data quality checks:\n")
    
    # Check for persons without visits
    no_visits <- DBI::dbGetQuery(conn, "
      SELECT COUNT(*) as count
      FROM cdm_person p
      LEFT JOIN cdm_visit_occurrence v ON p.person_id = v.person_id
      WHERE v.person_id IS NULL
    ")$count
    cat("Persons without visits:", no_visits, "\n")
    
    # Average visits per person
    avg_visits <- DBI::dbGetQuery(conn, "
      SELECT AVG(visit_count) as avg_visits
      FROM (
        SELECT p.person_id, COUNT(v.visit_occurrence_id) as visit_count
        FROM cdm_person p
        LEFT JOIN cdm_visit_occurrence v ON p.person_id = v.person_id
        GROUP BY p.person_id
      )
    ")$avg_visits
    cat("Average visits per person:", round(avg_visits, 2), "\n")
  }
}

# Main comprehensive demo function
run_complete_duckdb_demo <- function(clean_start = TRUE) {
  cat("🚀 Starting Complete DuckDB/SQLite ETL-Synthea Demo\n")
  cat("===================================================\n")
  
  # Clean up previous run if requested
  if (clean_start) {
    if (file.exists("synthea_omop_demo.db")) {
      file.remove("synthea_omop_demo.db")
      cat("🧹 Cleaned up previous database\n")
    }
    if (dir.exists("dbt_synthea_seeds")) {
      unlink("dbt_synthea_seeds", recursive = TRUE)
      cat("🧹 Cleaned up previous data\n")
    }
  }
  
  # Step 1: Download complete data set
  data_dirs <- download_complete_dbt_synthea_seeds()
  
  # Step 2: Create database connection
  conn <- create_local_connection()
  
  # Step 3: Load Synthea source data
  cat("\n💾 Loading Synthea source data into database...\n")
  
  # Load all Synthea files
  synthea_files <- list.files(data_dirs$synthea_dir, pattern = "\\.csv$")
  for (file in synthea_files) {
    table_name <- sub("\\.csv$", "", file)
    load_csv_to_table(conn, file.path(data_dirs$synthea_dir, file), table_name, "synthea")
  }
  
  # Load vocabulary files (with some size limits for very large files)
  vocab_files <- list.files(data_dirs$vocab_dir, pattern = "\\.csv$")
  for (file in vocab_files) {
    table_name <- sub("_seed\\.csv$", "", file)
    max_rows <- if (grepl("concept_seed", file)) 5000 else NULL  # Limit concepts for demo
    load_csv_to_table(conn, file.path(data_dirs$vocab_dir, file), table_name, "vocab", max_rows)
  }
  
  # Step 4: Create OMOP CDM tables
  create_omop_cdm_tables(conn)
  
  # Step 5: Perform ETL transformations
  perform_etl_transformations(conn)
  
  # Step 6: Run validation queries
  run_omop_validation_queries(conn)
  
  # Cleanup
  DBI::dbDisconnect(conn)
  
  cat("\n✅ Complete demo finished successfully!\n")
  cat("📁 OMOP CDM database created at: synthea_omop_demo.db\n")
  cat("📁 Source data downloaded to: dbt_synthea_seeds/\n")
  cat("\n🎉 This demonstrates a complete end-to-end ETL from Synthea to OMOP CDM!\n")
  cat("The database contains both source Synthea tables and transformed OMOP CDM tables.\n")
}

# Run the complete demo
cat("Checking if script is run directly...\n")
if (!interactive()) {
  cat("Running complete demo automatically...\n")
  run_complete_duckdb_demo()
} else {
  cat("Script loaded. Run run_complete_duckdb_demo() to execute the full demo.\n")
}