# SteamAnalytics

**Course:** Software Modeling and Analysis, Plovdiv University  
**Faculty number:** `2401322008`  
**Project:** Steam-inspired relational database, Data Warehouse and Power BI analytics

## Description

A small educational Steam-inspired gaming platform model supporting users, games, genres, purchases and payments, owned-game libraries, gameplay sessions and game reviews. Data is synthetic and is not affiliated with Valve or Steam.

## Requirements and tools

- SQL Server and SQL Server Management Studio (SSMS)
- Power BI Desktop (to open the `.pbix` report)
- diagrams.net/draw.io (to edit `.drawio` diagrams)
- Git for version control

## Installation and execution

1. Download or clone the repository, and locate this `SteamAnalytics` directory.
2. Open SSMS and connect to your SQL Server instance.
3. Execute the scripts **in this order**:
   1. `sql/01_Schema.sql` — creates the operational database and tables.
   2. `sql/02_Logic.sql` — creates two functions, two triggers and two stored procedures.
   3. `sql/03_Seed.sql` — populates the operational database with synthetic test data.
   4. `sql/04_Tests.sql` — checks operational integrity and reports data summaries.
   5. `sql/05_Warehouse.sql` — creates the `dw` schema, fact/dimension tables and bridge.
   6. `sql/06_ETL.sql` — loads the Data Warehouse from operational tables.
   7. `sql/07_DW_Tests.sql` — checks warehouse row counts, revenue and genre weights.
4. Open `powerbi/SteamAnalytics.pbix` in Power BI Desktop. If the report cannot refresh, update its data-source settings to point to your local SQL Server instance and the `SteamAnalytics` database. Choose appropriate authentication and refresh.
5. Open diagram files in `diagrams/` using diagrams.net, if required.

**WARNING:** `01_Schema.sql` can **drop and recreate the entire `SteamAnalytics` database**, destroying existing data with that database name. Use a development database and back up anything important before running it. Do not rerun it merely to open the Power BI report.

## Validation results from the development dataset

The SQL scripts were executed in SSMS with the following observed results:

| Metric                                    |        Result |
| ----------------------------------------- | ------------: |
| Users                                     |            30 |
| Games                                     |            12 |
| Purchases                                 |            90 |
| Completed purchase items / FactSales rows |            72 |
| Library entries                           |            72 |
| Gameplay sessions / FactGameplay rows     |           216 |
| Reviews / FactReviews rows                |            36 |
| Completed sales revenue                   |       1477.40 |
| Gameplay duration, minutes                |         22458 |
| Average review rating                     |          3.00 |
| Operational integrity checks              | 4 of 4 passed |
| Warehouse integrity checks                | 6 of 6 passed |

The Power BI report should reproduce these aggregates when connected to the same database and refreshed.

## Project files

- `diagrams/Conceptual_Chen.drawio` — conceptual model
- `diagrams/Logical_CrowsFoot.drawio` — logical model
- `diagrams/Warehouse_UML.drawio` — physical Data Warehouse model
- `sql/01_Schema.sql` through `sql/07_DW_Tests.sql` — implementation, sample data and verification
- `powerbi/SteamAnalytics.pbix` — Power BI report
