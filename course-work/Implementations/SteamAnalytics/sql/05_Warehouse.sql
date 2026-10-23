/* SteamAnalytics DW: run once after 01_Schema.sql. The ETL script handles reloads. */

USE SteamAnalytics;
GO

IF SCHEMA_ID(N'dw') IS NULL
    EXEC(N'CREATE SCHEMA dw');
GO


CREATE TABLE dw.DimDate (
    DateKey INT NOT NULL
        PRIMARY KEY,

    CalendarDate DATE NOT NULL
        UNIQUE,

    [Year] SMALLINT NOT NULL,

    [Quarter] TINYINT NOT NULL,

    [Month] TINYINT NOT NULL,

    MonthName NVARCHAR(20) NOT NULL
);


CREATE TABLE dw.DimUser (
    UserKey INT NOT NULL
        PRIMARY KEY,

    Username NVARCHAR(60) NOT NULL,

    Country NVARCHAR(80) NOT NULL
);


CREATE TABLE dw.DimGame (
    GameKey INT NOT NULL
        PRIMARY KEY,

    Title NVARCHAR(160) NOT NULL,

    ReleaseDate DATE NOT NULL,

    CurrentPrice DECIMAL(12,2) NOT NULL
);


CREATE TABLE dw.DimGenre (
    GenreKey INT NOT NULL
        PRIMARY KEY,

    GenreName NVARCHAR(80) NOT NULL
);


CREATE TABLE dw.DimPaymentMethod (
    PaymentMethodKey TINYINT NOT NULL
        PRIMARY KEY,

    MethodName VARCHAR(20) NOT NULL
        UNIQUE
);


CREATE TABLE dw.DimReviewRating (
    RatingKey TINYINT NOT NULL
        PRIMARY KEY,

    RatingLabel NVARCHAR(20) NOT NULL
);


/* Bridge represents multi-genre games, and is NOT joined directly into base total-revenue measures. */

CREATE TABLE dw.BridgeGameGenre (
    GameKey INT NOT NULL
        REFERENCES dw.DimGame(GameKey),

    GenreKey INT NOT NULL
        REFERENCES dw.DimGenre(GenreKey),

    GenreWeight DECIMAL(12,6) NOT NULL
        CHECK (GenreWeight > 0 AND GenreWeight <= 1),

    CONSTRAINT PK_dw_BridgeGameGenre
        PRIMARY KEY (GameKey, GenreKey)
);


CREATE TABLE dw.FactSales (
    PurchaseItemKey INT NOT NULL
        PRIMARY KEY, /* source PurchaseItemId, grain: completed purchase item */

    PurchaseId INT NOT NULL,

    DateKey INT NOT NULL
        REFERENCES dw.DimDate(DateKey),

    UserKey INT NOT NULL
        REFERENCES dw.DimUser(UserKey),

    GameKey INT NOT NULL
        REFERENCES dw.DimGame(GameKey),

    PaymentMethodKey TINYINT NOT NULL
        REFERENCES dw.DimPaymentMethod(PaymentMethodKey),

    UnitsSold INT NOT NULL
        CONSTRAINT CK_dw_Sales_Units
            CHECK (UnitsSold = 1),

    Revenue DECIMAL(12,2) NOT NULL
        CHECK (Revenue >= 0)
);


CREATE TABLE dw.FactGameplay (
    SessionKey INT NOT NULL
        PRIMARY KEY, /* source SessionId, grain: completed gameplay session */

    DateKey INT NOT NULL
        REFERENCES dw.DimDate(DateKey),

    UserKey INT NOT NULL
        REFERENCES dw.DimUser(UserKey),

    GameKey INT NOT NULL
        REFERENCES dw.DimGame(GameKey),

    SessionCount INT NOT NULL
        CONSTRAINT CK_dw_Gameplay_Count
            CHECK (SessionCount = 1),

    DurationMinutes DECIMAL(12,2) NOT NULL
        CHECK (DurationMinutes > 0)
);


CREATE TABLE dw.FactReviews (
    ReviewKey INT NOT NULL
        PRIMARY KEY, /* source ReviewId, grain: current review */

    DateKey INT NOT NULL
        REFERENCES dw.DimDate(DateKey),

    UserKey INT NOT NULL
        REFERENCES dw.DimUser(UserKey),

    GameKey INT NOT NULL
        REFERENCES dw.DimGame(GameKey),

    RatingKey TINYINT NOT NULL
        REFERENCES dw.DimReviewRating(RatingKey),

    ReviewCount INT NOT NULL
        CONSTRAINT CK_dw_Reviews_Count
            CHECK (ReviewCount = 1)
);

GO

PRINT '05_Warehouse complete: 3 facts, 6 dimensions, 1 genre bridge.';
