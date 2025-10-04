# Code for filtering a synthea database, by removing any concepts from the vocab that do not appear
# in the data (including ancestors) and includes concepts included in the typical DQD checks.
# Also fixes some inconsistencies with CDM.

library(DatabaseConnector)
library(dplyr)

##Set-Up Variables database and CDM Variables fo the script o run
dbms <- ""
server  <- ""
user <- ""
password <- ""
pathToDriver <- ""
cdmVersion<-""

##Name of current schema
cdmSchema      <- ""
##Name of schema you would like the filtered cdm to exist in
cdmSchemaFiltered<-""


# Select concepts used in the CDM ------------------------------------------------------------------

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms     = dbms,
  server   = server,
  user     = user,
  password = password,
  pathToDriver = pathToDriver
)

connection <- DatabaseConnector::connect(connectionDetails)

DatabaseConnector::executeSql(connection, paste("drop schema if exists ", cdmSchemaFiltered, " cascade",sep=""))
DatabaseConnector::executeSql(connection, paste("create schema ", cdmSchemaFiltered,sep=""))
DatabaseConnector::executeSql(connection, paste("create table ", cdmSchemaFiltered, ".source_to_source_vocab_map as select * from ", cdmSchema, ".source_to_source_vocab_map limit 1",sep=""))
DatabaseConnector::executeSql(connection, paste("delete from ", cdmSchemaFiltered, ".source_to_source_vocab_map",sep=""))
DatabaseConnector::executeSql(connection, paste("create table ", cdmSchemaFiltered, ".source_to_standard_vocab_map as select * from ", cdmSchema, ".source_to_standard_vocab_map limit 1",sep=""))
DatabaseConnector::executeSql(connection, paste("delete from ", cdmSchemaFiltered, ".source_to_standard_vocab_map",sep=""))

tables <- DatabaseConnector::getTableNames(connection, databaseSchema=cdmSchema)
# Note: Excluding concept_class, domain and vocabulary from vocab tables. We want to keep their
# concept IDs:
vocabTables <- c("concept",
                 "concept_ancestor",
                 "concept_relationship",
                 "concept_synonym",
                 "drug_strength",
                 "source_to_source_vocab_map",
                 "source_to_standard_vocab_map")
nonVocabTables <- tables[!tables %in% vocabTables]
conceptIds <- c()
# Todo: add unit concepts found in drug_strength table
for (table in nonVocabTables) {
  message(sprintf("Searching table %s", table))
  fields <- DatabaseConnector::dbListFields(connection, name=table, databaseSchema=cdmSchema)
  fields <- fields[grepl("concept_id$", fields)]
  for (field in fields) {
    message(sprintf("- Searching field %s", field))
    sql <- "SELECT DISTINCT @field FROM @schema.@table;"
    conceptIds <- unique(c(conceptIds, renderTranslateQuerySql(connection = connection,
                                                               sql = sql,
                                                               schema=cdmSchema,
                                                               table = table,
                                                               field = field)[, 1]))
  }
}

# Expand with all parents
DatabaseConnector::insertTable(connection = connection,
                               databaseSchema = cdmSchema,
                               tableName = "cids",
                               data = tibble(concept_id = conceptIds))
sql <- "SELECT DISTINCT ancestor_concept_id
FROM @schema.concept_ancestor
INNER JOIN @schema.cids
  ON descendant_concept_id = concept_id::integer;"
ancestorConceptIds <- renderTranslateQuerySql(connection, sql,
                                              schema=cdmSchema)[, 1]
conceptIds <- unique(c(conceptIds, ancestorConceptIds))

## Get DQD Concept IDS

dqd_concept_level_checks <-read.csv(paste("https://raw.githubusercontent.com/OHDSI/DataQualityDashboard/main/inst/csv/OMOP_CDMv",cdmVersion,"_Concept_Level.csv",sep=""))

dqdIds<- unique(c( dqd_concept_level_checks$unitConceptId,
                   unlist(strsplit(unique(dqd_concept_level_checks$conceptId),",")), ## Handle lists of concept ids
                   unlist(strsplit(unique(dqd_concept_level_checks$plausibleUnitConceptIds),","))
))

#Remove NAs and -1s in file
dqdIds<-dqdIds[!is.na(dqdIds) & dqdIds>0]

conceptIds<-unique(c(conceptIds,dqdIds))

# Filter data to selected concept IDs --------------------------------------------------------------
DatabaseConnector::insertTable(connection = connection,
                               databaseSchema = cdmSchema,
                               tableName = "#cids",
                               data = tibble(concept_id = conceptIds),
                               tempTable = TRUE,
                               dropTableIfExists = TRUE)

sql <- readLines(paste("https://raw.githubusercontent.com/OHDSI/CommonDataModel/main/inst/ddl/",cdmVersion,"/",dbms,"/OMOPCDM_",dbms,"_",cdmVersion,"_ddl.sql",sep=''))
sql <- SqlRender::render(paste(sql, collapse = "\n"), cdmDatabaseSchema = cdmSchemaFiltered)
# Convert all non-concept IDs to BIGINT because data requires this:
sql <- gsub("concept_id BIGINT", "concept_id integer", gsub("_id integer", "_id BIGINT", sql))
executeSql(connection, sql)

fixDates <- function(data) {
  # For some reason dates in source database vocab tables are stored as numeric (not compatible with
  # CDM), so convert them to Date:
  for (field in colnames(data)[grepl("_date", colnames(data), ignore.case = TRUE)]) {
    data[, field] <- as.Date(as.character(data[, field]), format("%Y%m%d"))
  }
  return(data)
}

# Filter vocab tables
for (table in vocabTables) {
  message(sprintf("Filtering table %s", table))
  fields <- DatabaseConnector::dbListFields(connection, name=table, databaseSchema=cdmSchema)
  fields <- fields[grepl("concept_id", fields)]
  sql <- paste0("SELECT * FROM @schema.@table WHERE ",
                paste(paste(fields, "IN (SELECT concept_id::integer FROM @schema.cids)"), collapse = " AND "),
                ";")
  data <- renderTranslateQuerySql(connection, sql, table = table,schema=cdmSchema)
  colnames(data) <- tolower(colnames(data))
  #data <- fixDates(data)
  insertTable(connection = connection,
              databaseSchema = cdmSchemaFiltered,
              tableName = toupper(table),
              data = data,
              tempTable = FALSE,
              createTable = FALSE,
              dropTableIfExists = FALSE,
              progressBar = TRUE)
}

disconnect(connection)


