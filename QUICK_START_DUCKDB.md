# Quick Start: DuckDB Demo

This is a 5-minute quick start guide to run the ETL-Synthea demo with DuckDB/SQLite using data from @OHDSI/dbt-synthea.

## Prerequisites

- R (version 4.0+)
- Internet connection (for downloading data)

## Step 1: Install Required R Packages

```r
# Install required packages if not already installed
if (!requireNamespace("DBI", quietly = TRUE)) {
  install.packages("DBI")
}

if (!requireNamespace("RSQLite", quietly = TRUE)) {
  install.packages("RSQLite")
}

# Optional: Install DuckDB for better performance
# install.packages("duckdb")  # May not work on all systems
```

## Step 2: Run the Simple Demo (Recommended)

```r
# Load the demo script
source("extras/duckdb_demo_simple.R")

# Run the demo
run_duckdb_demo()
```

**Expected Output:**
```
🚀 Starting DuckDB/SQLite ETL-Synthea Demo
📥 Downloading seed data from OHDSI/dbt-synthea repository...
📦 Download complete! (8 files)
🗃️ Creating SQLite connection at: synthea_demo.db
💾 Loading data into database...
✓ Loaded patients with 27 rows
✓ Loaded encounters with 604 rows
[... more tables ...]
🔍 Running demonstration queries...
📊 Total patients: 27
✅ Demo completed successfully!
```

## Step 3: Run the Complete Demo (Optional)

For a full ETL demonstration with OMOP CDM transformation:

```r
# Load the complete demo script
source("extras/duckdb_demo_complete.R")

# Run the complete demo (takes longer, downloads more data)
run_complete_duckdb_demo()
```

## Step 4: Explore Results

After running the demo, you'll have:

- **Database file**: `synthea_demo.db` or `synthea_omop_demo.db`
- **Data directory**: `dbt_synthea_seeds/` with all CSV files

You can explore the database using any SQLite browser or R:

```r
library(DBI)
conn <- dbConnect(RSQLite::SQLite(), "synthea_demo.db")

# List all tables
dbListTables(conn)

# Query patient data
dbGetQuery(conn, "SELECT * FROM patients LIMIT 5")

# Close connection
dbDisconnect(conn)
```

## What the Demo Does

1. **Downloads real data** from @OHDSI/dbt-synthea repository
2. **Creates local database** (DuckDB preferred, SQLite fallback)
3. **Loads Synthea data** (patients, encounters, conditions, etc.)
4. **Loads OMOP vocabulary** (concepts, domains, etc.)
5. **Performs ETL transformation** (complete demo only)
6. **Validates results** with summary queries

## Data Included

- **27 synthetic patients** with realistic healthcare journeys
- **604 clinical encounters** (inpatient, outpatient, emergency)
- **438 medical conditions** with proper coding
- **990+ clinical observations** and measurements
- **OMOP vocabulary subset** relevant to the synthetic data

## Troubleshooting

**Q: "DuckDB package not available"**
A: This is normal. The demo automatically uses SQLite as a fallback.

**Q: Download failures**
A: Check internet connection. The demo continues with successfully downloaded files.

**Q: "Error in library(...)"**
A: Install missing packages using `install.packages("package_name")`.

## Next Steps

- Explore the generated database with your favorite SQL tool
- Modify the demo scripts to add custom transformations
- Integrate with the full ETLSyntheaBuilder package for production use
- Try the demo with your own Synthea-generated data

## Files Created

- `synthea_demo.db` - Local database with all data
- `dbt_synthea_seeds/` - Downloaded CSV files
- `README_DUCKDB_DEMO.md` - Detailed documentation

This demo provides a complete working example of loading and transforming synthetic healthcare data using modern data engineering tools!