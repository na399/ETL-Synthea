test_that("DuckDB demo functionality works", {
  skip_if_not(requireNamespace("DBI", quietly = TRUE), "DBI package not available")
  skip_if_not(requireNamespace("RSQLite", quietly = TRUE), "RSQLite package not available")
  
  # Find the package root by going up from tests/testthat
  pkg_root <- file.path(dirname(dirname(getwd())))
  
  # Create a temporary directory for the test
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)
  
  # Source the demo script from the correct location
  demo_script <- file.path(pkg_root, "extras", "duckdb_demo_simple.R")
  skip_if_not(file.exists(demo_script), "Demo script not found")
  
  source(demo_script)
  
  # Test that the demo can at least load
  expect_true(exists("run_duckdb_demo"))
  expect_true(exists("download_dbt_synthea_seeds"))
  expect_true(exists("create_local_connection"))
  
  # Test database connection creation
  expect_no_error({
    conn <- create_local_connection("test_demo.db")
    DBI::dbDisconnect(conn)
  })
  
  # Clean up
  if (file.exists("test_demo.db")) {
    file.remove("test_demo.db")
  }
  
  setwd(old_wd)
})

test_that("Demo scripts exist and are readable", {
  # Find the package root by going up from tests/testthat  
  pkg_root <- file.path(dirname(dirname(getwd())))
  
  expect_true(file.exists(file.path(pkg_root, "extras", "duckdb_demo_simple.R")))
  expect_true(file.exists(file.path(pkg_root, "extras", "duckdb_demo_complete.R")))
  expect_true(file.exists(file.path(pkg_root, "README_DUCKDB_DEMO.md")))
})