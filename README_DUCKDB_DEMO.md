# DuckDB End-to-End Demo for ETL-Synthea

This directory contains a complete demonstration of the ETL-Synthea pipeline running end-to-end on a DuckDB local instance (with SQLite fallback) using data from the @OHDSI/dbt-synthea/seeds repository.

## Overview

The demo demonstrates:
1. **Data Download**: Automatically downloads Synthea and OMOP vocabulary seed data from the @OHDSI/dbt-synthea repository
2. **Local Database**: Creates a local DuckDB database (falls back to SQLite if DuckDB is unavailable)
3. **Source Data Loading**: Loads all Synthea tables and vocabulary tables from CSV files
4. **OMOP CDM Creation**: Creates OMOP Common Data Model tables 
5. **ETL Transformation**: Performs ETL transformations from Synthea format to OMOP CDM format
6. **Validation**: Runs validation queries to verify the transformation

## Demo Scripts

### 1. Simple Demo (`extras/duckdb_demo_simple.R`)
A lightweight demonstration that:
- Downloads essential Synthea files (patients, encounters, conditions, medications, observations)
- Downloads key vocabulary files (concepts, vocabulary, domains)
- Loads data into a local database
- Runs basic queries to demonstrate functionality

**Usage:**
```r
# Run from R
source("extras/duckdb_demo_simple.R")
run_duckdb_demo()

# Or run from command line
R --slave --no-restore --file=extras/duckdb_demo_simple.R
```

### 2. Complete Demo (`extras/duckdb_demo_complete.R`)
A comprehensive demonstration that:
- Downloads ALL Synthea and vocabulary files from @OHDSI/dbt-synthea/seeds
- Creates complete OMOP CDM table structure
- Performs full ETL transformation from Synthea to OMOP format
- Validates the resulting OMOP CDM data

**Usage:**
```r
# Run from R
source("extras/duckdb_demo_complete.R")
run_complete_duckdb_demo()

# Or run from command line
R --slave --no-restore --file=extras/duckdb_demo_complete.R
```

## Sample Output

The complete demo produces output similar to:

```
=== Complete DuckDB/SQLite ETL-Synthea Demo ===
===================================================

📥 Downloading complete seed data from OHDSI/dbt-synthea repository...
📦 Download complete! ( 27 files)

🗃️  Creating SQLite connection at: synthea_omop_demo.db 

💾 Loading Synthea source data into database...
  ✓ Loaded synthea_patients with 27 rows
  ✓ Loaded synthea_encounters with 604 rows
  ✓ Loaded synthea_conditions with 438 rows
  [... additional tables ...]

🏗️  Creating OMOP CDM tables...
  ✓ Created OMOP table: cdm_person 
  ✓ Created OMOP table: cdm_visit_occurrence 
  ✓ Created OMOP table: cdm_condition_occurrence 
  ✓ Created OMOP table: cdm_drug_exposure 

🔄 Performing ETL transformations to OMOP CDM...
  ✓ Transformed 27 patients to OMOP person table
  ✓ Transformed 604 encounters to OMOP visit_occurrence table
  ✓ Transformed 438 conditions to OMOP condition_occurrence table

📊 Running OMOP CDM validation queries...
👥 Total persons in CDM: 27 
🏥 Total visits in CDM: 604 
🩺 Total conditions in CDM: 438 

✅ Complete demo finished successfully!
🎉 This demonstrates a complete end-to-end ETL from Synthea to OMOP CDM!
```

## Output Files

After running the demo, you'll have:

1. **Database file**: `synthea_omop_demo.db` - Contains both source Synthea tables and transformed OMOP CDM tables
2. **Data directory**: `dbt_synthea_seeds/` - Contains all downloaded CSV files organized by type:
   - `dbt_synthea_seeds/synthea/` - Synthea source data files
   - `dbt_synthea_seeds/vocabulary/` - OMOP vocabulary files

## Database Schema

The demo creates tables in two main categories:

### Source Tables (Synthea format)
- `synthea_patients` - Patient demographics
- `synthea_encounters` - Healthcare encounters
- `synthea_conditions` - Medical conditions
- `synthea_medications` - Medication prescriptions
- `synthea_observations` - Clinical observations
- ... (plus all other Synthea tables)

### OMOP CDM Tables
- `cdm_person` - Transformed patient data in OMOP format
- `cdm_visit_occurrence` - Transformed encounter data
- `cdm_condition_occurrence` - Transformed condition data
- `cdm_drug_exposure` - Ready for medication data (structure created)

### Vocabulary Tables
- `vocab_concept` - OMOP standard concepts
- `vocab_vocabulary` - Vocabulary definitions
- `vocab_domain` - Domain classifications
- ... (plus all other OMOP vocabulary tables)

## Requirements

- **R** (version 4.0 or higher)
- **Required R packages**:
  - `DBI` - Database interface
  - `duckdb` (optional, preferred) - DuckDB database engine
  - `RSQLite` (fallback) - SQLite database engine

## Data Source

All data is automatically downloaded from the official @OHDSI/dbt-synthea repository at:
https://github.com/OHDSI/dbt-synthea/tree/main/seeds

This includes:
- **Synthea synthetic data**: 27 patients with realistic healthcare data
- **OMOP vocabulary subset**: Concepts relevant to the Synthea dataset

## Integration with ETLSyntheaBuilder

This demo demonstrates the core ETL principles used by the ETLSyntheaBuilder package but uses a simplified, self-contained approach. The transformation logic can be extended to use the full ETLSyntheaBuilder functionality for production use cases.

## Next Steps

1. **Extend transformations**: Add more sophisticated mapping logic using OMOP vocabulary
2. **Add more CDM tables**: Expand to include procedure_occurrence, drug_exposure, etc.
3. **Integrate with ETLSyntheaBuilder**: Use the full package functions for production ETL
4. **DuckDB optimization**: Add DuckDB-specific optimizations when available
5. **Data quality checks**: Add comprehensive OMOP CDM validation rules

## Troubleshooting

**Issue**: DuckDB package not available
**Solution**: The demo automatically falls back to SQLite, which provides the same functionality for demonstration purposes.

**Issue**: Download failures
**Solution**: Check internet connectivity. The demo will continue with successfully downloaded files.

**Issue**: Database locked errors
**Solution**: Ensure no other processes are using the database file, or delete the existing database file before running.