CREATE DATABASE profile_migration

USE profile_migration

CREATE TABLE windows(

    id INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    migration_status TINYINT NULL,
    single_profile  TINYINT NOT NULL,
    scan_date DATE NULL,
    load_date DATE NULL,
    old_domain VARCHAR(50) NULL,
    new_domain VARCHAR(50) NULL,
    old_name VARCHAR(50) NULL,
    new_name VARCHAR(50) NULL,
    old_os VARCHAR(50) NULL,
    new_os VARCHAR(50) NULL,
    old_workstation VARCHAR(50) NULL,
    new_workstation VARCHAR(50) NULL
)