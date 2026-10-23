/* SteamAnalytics; creates a clean course database. */

USE master;
GO

IF DB_ID(N'SteamAnalytics') IS NOT NULL
BEGIN
    ALTER DATABASE SteamAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SteamAnalytics;
END;
GO

CREATE DATABASE SteamAnalytics;
GO

USE SteamAnalytics;
GO


CREATE TABLE dbo.Users (
    UserId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Users PRIMARY KEY,

    Username NVARCHAR(60) NOT NULL
        CONSTRAINT UQ_Users_Username UNIQUE,

    Email NVARCHAR(255) NOT NULL
        CONSTRAINT UQ_Users_Email UNIQUE,

    Country NVARCHAR(80) NOT NULL,

    CreatedAt DATETIME2(0) NOT NULL
        CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME()
);


CREATE TABLE dbo.Games (
    GameId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Games PRIMARY KEY,

    Title NVARCHAR(160) NOT NULL,

    Description NVARCHAR(1000) NULL,

    Price DECIMAL(12,2) NOT NULL
        CONSTRAINT CK_Games_Price CHECK (Price >= 0),

    ReleaseDate DATE NOT NULL
);


CREATE TABLE dbo.Genres (
    GenreId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Genres PRIMARY KEY,

    Name NVARCHAR(80) NOT NULL
        CONSTRAINT UQ_Genres_Name UNIQUE,

    Description NVARCHAR(500) NULL
);


CREATE TABLE dbo.GameGenres (
    GameId INT NOT NULL
        REFERENCES dbo.Games(GameId),

    GenreId INT NOT NULL
        REFERENCES dbo.Genres(GenreId),

    CONSTRAINT PK_GameGenres
        PRIMARY KEY (GameId, GenreId)
);


CREATE TABLE dbo.Purchases (
    PurchaseId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Purchases PRIMARY KEY,

    UserId INT NOT NULL
        REFERENCES dbo.Users(UserId),

    PurchaseDate DATETIME2(0) NOT NULL
        CONSTRAINT DF_Purchases_PurchaseDate DEFAULT SYSUTCDATETIME(),

    Status VARCHAR(12) NOT NULL
        CONSTRAINT DF_Purchases_Status DEFAULT 'Pending'
        CONSTRAINT CK_Purchases_Status
            CHECK (Status IN ('Pending', 'Completed', 'Failed')),

    TotalAmount DECIMAL(12,2) NOT NULL
        CONSTRAINT CK_Purchases_Total CHECK (TotalAmount >= 0)
);


CREATE TABLE dbo.PurchaseItems (
    PurchaseItemId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_PurchaseItems PRIMARY KEY,

    PurchaseId INT NOT NULL
        REFERENCES dbo.Purchases(PurchaseId),

    GameId INT NOT NULL
        REFERENCES dbo.Games(GameId),

    UnitPrice DECIMAL(12,2) NOT NULL
        CONSTRAINT CK_PurchaseItems_UnitPrice CHECK (UnitPrice >= 0),

    CONSTRAINT UQ_PurchaseItems_Purchase_Game
        UNIQUE (PurchaseId, GameId)
);


CREATE TABLE dbo.Payments (
    PaymentId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Payments PRIMARY KEY,

    PurchaseId INT NOT NULL
        CONSTRAINT UQ_Payments_Purchase UNIQUE
        REFERENCES dbo.Purchases(PurchaseId),

    Amount DECIMAL(12,2) NOT NULL
        CONSTRAINT CK_Payments_Amount CHECK (Amount >= 0),

    Method VARCHAR(20) NOT NULL
        CONSTRAINT CK_Payments_Method
            CHECK (Method IN ('Card', 'PayPal', 'Bank')),

    Status VARCHAR(12) NOT NULL
        CONSTRAINT CK_Payments_Status
            CHECK (Status IN ('Pending', 'Completed', 'Failed')),

    PaidAt DATETIME2(0) NULL,

    CONSTRAINT CK_Payments_PaidAt
        CHECK (
            (Status = 'Completed' AND PaidAt IS NOT NULL)
            OR
            (Status <> 'Completed' AND PaidAt IS NULL)
        )
);


CREATE TABLE dbo.LibraryEntries (
    LibraryEntryId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_LibraryEntries PRIMARY KEY,

    UserId INT NOT NULL
        REFERENCES dbo.Users(UserId),

    GameId INT NOT NULL
        REFERENCES dbo.Games(GameId),

    AddedAt DATETIME2(0) NOT NULL
        CONSTRAINT DF_LibraryEntries_AddedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT UQ_LibraryEntries_User_Game
        UNIQUE (UserId, GameId)
);


CREATE TABLE dbo.GameplaySessions (
    SessionId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_GameplaySessions PRIMARY KEY,

    LibraryEntryId INT NOT NULL
        REFERENCES dbo.LibraryEntries(LibraryEntryId),

    StartedAt DATETIME2(0) NOT NULL,

    EndedAt DATETIME2(0) NOT NULL,

    CONSTRAINT CK_GameplaySessions_Dates
        CHECK (EndedAt > StartedAt)
);


CREATE TABLE dbo.Reviews (
    ReviewId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Reviews PRIMARY KEY,

    UserId INT NOT NULL
        REFERENCES dbo.Users(UserId),

    GameId INT NOT NULL
        REFERENCES dbo.Games(GameId),

    Rating TINYINT NOT NULL
        CONSTRAINT CK_Reviews_Rating
            CHECK (Rating BETWEEN 1 AND 5),

    Comment NVARCHAR(1000) NULL,

    CreatedAt DATETIME2(0) NOT NULL
        CONSTRAINT DF_Reviews_CreatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT UQ_Reviews_User_Game
        UNIQUE (UserId, GameId),

    CONSTRAINT FK_Reviews_Ownership
        FOREIGN KEY (UserId, GameId)
        REFERENCES dbo.LibraryEntries(UserId, GameId)
);


/* Supporting audit table is an implementation detail, not a new domain entity. */

CREATE TABLE dbo.ReviewAudit (
    AuditId BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_ReviewAudit PRIMARY KEY,

    ReviewId INT NOT NULL,

    ActionType VARCHAR(6) NOT NULL,

    OldRating TINYINT NULL,

    NewRating TINYINT NULL,

    ChangedAt DATETIME2(0) NOT NULL
        CONSTRAINT DF_ReviewAudit_ChangedAt DEFAULT SYSUTCDATETIME()
);


CREATE INDEX IX_Purchases_User_Date
    ON dbo.Purchases(UserId, PurchaseDate);

CREATE INDEX IX_PurchaseItems_Game
    ON dbo.PurchaseItems(GameId);

CREATE INDEX IX_GameplaySessions_Library_Date
    ON dbo.GameplaySessions(LibraryEntryId, StartedAt);

CREATE INDEX IX_Reviews_Game
    ON dbo.Reviews(GameId);

GO

PRINT '01_Schema completed';
