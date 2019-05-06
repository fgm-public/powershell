CREATE DATABASE backups

USE backups

CREATE TABLE users(

    id INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    last_backup DATE NULL,
    first_backup DATE NULL,
    user_name VARCHAR(50) NULL,
    computer_name VARCHAR(50) NULL,
)