-- Example SQL initialization script
-- Place this in sql-scripts folder to run at startup

-- Create database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'YourDatabase')
BEGIN
    CREATE DATABASE YourDatabase;
END
GO

USE YourDatabase;
GO

-- Create example table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Users' AND xtype='U')
BEGIN
    CREATE TABLE Users (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Username NVARCHAR(50) NOT NULL,
        Email NVARCHAR(100) NOT NULL,
        CreatedAt DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- Insert test data
IF NOT EXISTS (SELECT * FROM Users)
BEGIN
    INSERT INTO Users (Username, Email) VALUES 
    ('admin', 'admin@example.com'),
    ('user1', 'user1@example.com');
END
GO

PRINT 'Database initialization completed successfully!';
