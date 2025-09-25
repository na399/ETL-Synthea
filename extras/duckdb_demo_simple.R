######################################
## Simple DuckDB End-to-End Demo for ETL-Synthea ##
######################################

cat("=== DuckDB/SQLite ETL-Synthea Demo ===\n\n")

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

# Function to download seed data from OHDSI/dbt-synthea repository
download_dbt_synthea_seeds <- function(target_dir = "dbt_synthea_seeds") {
  cat("\n📥 Downloading seed data from OHDSI/dbt-synthea repository...\n")
  
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
  
  # Download a subset of files for the demo to keep it manageable
  essential_files <- list(
    synthea = c("patients.csv", "encounters.csv", "conditions.csv", "medications.csv", "observations.csv"),
    vocabulary = c("concept_seed.csv", "vocabulary_seed.csv", "domain_seed.csv")
  )
  
  download_count <- 0
  
  # Download essential Synthea files
  cat("Downloading essential Synthea files...\n")
  for (file in essential_files$synthea) {
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
  
  # Download essential vocabulary files (with size limits for demo)
  cat("Downloading essential vocabulary files...\n")
  for (file in essential_files$vocabulary) {
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
create_local_connection <- function(db_path = "synthea_demo.db") {
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

# Load CSV file into database table
load_csv_to_table <- function(conn, csv_path, table_name, max_rows = NULL) {
  if (!file.exists(csv_path)) {
    cat("  ⚠ File not found:", csv_path, "\n")
    return(FALSE)
  }
  
  tryCatch({
    # Read CSV with optional row limit for large files
    if (is.null(max_rows)) {
      data <- read.csv(csv_path, stringsAsFactors = FALSE)
    } else {
      data <- read.csv(csv_path, stringsAsFactors = FALSE, nrows = max_rows)
    }
    
    # Write to database
    DBI::dbWriteTable(conn, table_name, data, overwrite = TRUE)
    cat("  ✓ Loaded", table_name, "with", nrow(data), "rows\n")
    return(TRUE)
  }, error = function(e) {
    cat("  ✗ Error loading", table_name, ":", e$message, "\n")
    return(FALSE)
  })
}

# Run demonstration queries
run_demo_queries <- function(conn) {
  cat("\n🔍 Running demonstration queries...\n")
  
  # Check which tables are available
  tables <- DBI::dbListTables(conn)
  cat("Available tables:", paste(tables, collapse = ", "), "\n\n")
  
  # Demo queries based on available tables
  if ("patients" %in% tables) {
    # Count patients
    result <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as patient_count FROM patients")
    cat("📊 Total patients:", result$patient_count, "\n")
    
    # Show sample patient data
    sample_patients <- DBI::dbGetQuery(conn, "
      SELECT Id, BIRTHDATE, DEATHDATE, FIRST, LAST, GENDER 
      FROM patients 
      LIMIT 5
    ")
    cat("\n👥 Sample patients:\n")
    print(sample_patients)
  }
  
  if ("encounters" %in% tables) {
    # Count encounters
    result <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as encounter_count FROM encounters")
    cat("\n🏥 Total encounters:", result$encounter_count, "\n")
  }
  
  if ("conditions" %in% tables) {
    # Count conditions
    result <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as condition_count FROM conditions")
    cat("🩺 Total conditions:", result$condition_count, "\n")
  }
  
  if ("concept" %in% tables) {
    # Show vocabulary info
    result <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as concept_count FROM concept")
    cat("📚 Total concepts (sample):", result$concept_count, "\n")
  }
  
  # Complex query if we have patients and encounters
  if (all(c("patients", "encounters") %in% tables)) {
    cat("\n🔗 Patient-encounter summary:\n")
    result <- DBI::dbGetQuery(conn, "
      SELECT 
        p.GENDER,
        COUNT(*) as patient_count,
        AVG(encounter_count) as avg_encounters_per_patient
      FROM (
        SELECT 
          p.Id,
          p.GENDER,
          COUNT(e.Id) as encounter_count
        FROM patients p
        LEFT JOIN encounters e ON p.Id = e.PATIENT
        GROUP BY p.Id, p.GENDER
      ) p
      GROUP BY p.GENDER
    ")
    print(result)
  }
}

# Main demo function
run_duckdb_demo <- function(clean_start = TRUE) {
  cat("🚀 Starting DuckDB/SQLite ETL-Synthea Demo\n")
  cat("========================================\n")
  
  # Clean up previous run if requested
  if (clean_start) {
    if (file.exists("synthea_demo.db")) {
      file.remove("synthea_demo.db")
      cat("🧹 Cleaned up previous database\n")
    }
    if (dir.exists("dbt_synthea_seeds")) {
      unlink("dbt_synthea_seeds", recursive = TRUE)
      cat("🧹 Cleaned up previous data\n")
    }
  }
  
  # Step 1: Download data
  data_dirs <- download_dbt_synthea_seeds()
  
  # Step 2: Create database connection
  conn <- create_local_connection()
  
  # Step 3: Load data into database
  cat("\n💾 Loading data into database...\n")
  
  # Load Synthea data
  load_csv_to_table(conn, file.path(data_dirs$synthea_dir, "patients.csv"), "patients")
  load_csv_to_table(conn, file.path(data_dirs$synthea_dir, "encounters.csv"), "encounters")
  load_csv_to_table(conn, file.path(data_dirs$synthea_dir, "conditions.csv"), "conditions")
  load_csv_to_table(conn, file.path(data_dirs$synthea_dir, "medications.csv"), "medications")
  load_csv_to_table(conn, file.path(data_dirs$synthea_dir, "observations.csv"), "observations")
  
  # Load vocabulary data (with row limits for demo)
  load_csv_to_table(conn, file.path(data_dirs$vocab_dir, "concept_seed.csv"), "concept", max_rows = 1000)
  load_csv_to_table(conn, file.path(data_dirs$vocab_dir, "vocabulary_seed.csv"), "vocabulary")
  load_csv_to_table(conn, file.path(data_dirs$vocab_dir, "domain_seed.csv"), "domain")
  
  # Step 4: Run demonstration queries
  run_demo_queries(conn)
  
  # Cleanup
  DBI::dbDisconnect(conn)
  
  cat("\n✅ Demo completed successfully!\n")
  cat("📁 Database created at: synthea_demo.db\n")
  cat("📁 Data downloaded to: dbt_synthea_seeds/\n")
  cat("\nThis demonstrates loading OHDSI/dbt-synthea seed data into a local database.\n")
  cat("The next step would be to run ETL transformations to convert this to OMOP CDM format.\n")
}

# Run the demo
cat("Checking if script is run directly...\n")
if (!interactive()) {
  cat("Running demo automatically...\n")
  run_duckdb_demo()
} else {
  cat("Script loaded. Run run_duckdb_demo() to execute the demo.\n")
}