# 🗄️ Database Setup & Initialization Guide

This directory contains the necessary files to set up the DataWarehouse database. You can initialize the database by restoring the provided backup file (recommended) or by importing the raw CSV datasets manually.

## 📁 Folder Structure

* **`DataWarehouse.bak`**: The full database backup file for SQL Server.


* **`csv_files/`**: Raw data files used for manual import or specific data warehousing ETL tasks.


* **`README`**: This instructional guide.



## 🛠️ Method 1: Database Restore (.bak) - *SQL Server Only (Recommended)*

The easiest way to set up the database is to restore the provided `DataWarehouse.bak` file.

1. Move the `DataWarehouse.bak` file to your SQL Server's default backup directory (typically `C:\Program Files\Microsoft SQL Server\...\MSSQL\Backup`).


2. In SSMS, right-click **Databases** -> **Restore Database**.
3. Select **Device**, click the `...` button, and click **Add** to locate your `DataWarehouse.bak` file.


4. Click **OK** to restore.
5. Refresh your Object Explorer to access the database.

## 🛠️ Method 2: Manual CSV Import

If you prefer to build the tables yourself or practice data ingestion, you can manually import the files from the `csv_files` folder.

1. Create a new, blank database in your DBMS (e.g., `DataWarehouse`).
2. In SSMS, right-click the new database -> **Tasks** -> **Import Flat File**.
3. Browse and select one of the CSV files in the `csv_files` folder.


4. Follow the import wizard, ensuring you allow NULLs where appropriate based on the data preview.
5. Repeat this process for the remaining files in the directory.