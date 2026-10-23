/* FULL REFRESH ETL: safe to rerun after warehouse is created. */

USE SteamAnalytics;
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    DELETE FROM dw.FactReviews;
    DELETE FROM dw.FactGameplay;
    DELETE FROM dw.FactSales;
    DELETE FROM dw.BridgeGameGenre;
    DELETE FROM dw.DimReviewRating;
    DELETE FROM dw.DimPaymentMethod;
    DELETE FROM dw.DimGenre;
    DELETE FROM dw.DimGame;
    DELETE FROM dw.DimUser;
    DELETE FROM dw.DimDate;


    INSERT dw.DimUser(UserKey, Username, Country)
    SELECT
        UserId,
        Username,
        Country
    FROM dbo.Users;


    INSERT dw.DimGame(GameKey, Title, ReleaseDate, CurrentPrice)
    SELECT
        GameId,
        Title,
        ReleaseDate,
        Price
    FROM dbo.Games;


    INSERT dw.DimGenre(GenreKey, GenreName)
    SELECT
        GenreId,
        Name
    FROM dbo.Genres;


    INSERT dw.DimPaymentMethod(PaymentMethodKey, MethodName)
    VALUES
        (1, 'Card'),
        (2, 'PayPal'),
        (3, 'Bank');


    INSERT dw.DimReviewRating(RatingKey, RatingLabel)
    VALUES
        (1, '1 star'),
        (2, '2 stars'),
        (3, '3 stars'),
        (4, '4 stars'),
        (5, '5 stars');


    INSERT dw.BridgeGameGenre(GameKey, GenreKey, GenreWeight)
    SELECT
        gg.GameId,
        gg.GenreId,
        CAST(
            1.0 / COUNT(*) OVER (PARTITION BY gg.GameId)
            AS DECIMAL(12,6)
        )
    FROM dbo.GameGenres gg;


    ;WITH Dates AS (
        SELECT
            CAST(p.PurchaseDate AS DATE) AS d
        FROM dbo.Purchases p
        WHERE p.Status = 'Completed'

        UNION

        SELECT
            CAST(s.StartedAt AS DATE)
        FROM dbo.GameplaySessions s

        UNION

        SELECT
            CAST(r.CreatedAt AS DATE)
        FROM dbo.Reviews r
    )
    INSERT dw.DimDate(
        DateKey,
        CalendarDate,
        [Year],
        [Quarter],
        [Month],
        MonthName
    )
    SELECT
        YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d),
        d,
        YEAR(d),
        DATEPART(QUARTER, d),
        MONTH(d),
        DATENAME(MONTH, d)
    FROM Dates;


    INSERT dw.FactSales(
        PurchaseItemKey,
        PurchaseId,
        DateKey,
        UserKey,
        GameKey,
        PaymentMethodKey,
        UnitsSold,
        Revenue
    )
    SELECT
        pi.PurchaseItemId,
        p.PurchaseId,
        YEAR(p.PurchaseDate) * 10000
            + MONTH(p.PurchaseDate) * 100
            + DAY(p.PurchaseDate),
        p.UserId,
        pi.GameId,
        CASE pay.Method
            WHEN 'Card' THEN 1
            WHEN 'PayPal' THEN 2
            WHEN 'Bank' THEN 3
        END,
        1,
        pi.UnitPrice
    FROM dbo.PurchaseItems pi
    JOIN dbo.Purchases p
        ON p.PurchaseId = pi.PurchaseId
        AND p.Status = 'Completed'
    JOIN dbo.Payments pay
        ON pay.PurchaseId = p.PurchaseId
        AND pay.Status = 'Completed';


    INSERT dw.FactGameplay(
        SessionKey,
        DateKey,
        UserKey,
        GameKey,
        SessionCount,
        DurationMinutes
    )
    SELECT
        s.SessionId,
        YEAR(s.StartedAt) * 10000
            + MONTH(s.StartedAt) * 100
            + DAY(s.StartedAt),
        l.UserId,
        l.GameId,
        1,
        CAST(
            DATEDIFF_BIG(SECOND, s.StartedAt, s.EndedAt) / 60.0
            AS DECIMAL(12,2)
        )
    FROM dbo.GameplaySessions s
    JOIN dbo.LibraryEntries l
        ON l.LibraryEntryId = s.LibraryEntryId;


    INSERT dw.FactReviews(
        ReviewKey,
        DateKey,
        UserKey,
        GameKey,
        RatingKey,
        ReviewCount
    )
    SELECT
        r.ReviewId,
        YEAR(r.CreatedAt) * 10000
            + MONTH(r.CreatedAt) * 100
            + DAY(r.CreatedAt),
        r.UserId,
        r.GameId,
        r.Rating,
        1
    FROM dbo.Reviews r;

    COMMIT;

    PRINT '06_ETL successfully refreshed warehouse.';
END TRY

BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK;

    THROW;
END CATCH;

GO


SELECT
    'FactSales' AS Entity,
    COUNT(*) AS RowsLoaded
FROM dw.FactSales

UNION ALL

SELECT
    'FactGameplay',
    COUNT(*)
FROM dw.FactGameplay

UNION ALL

SELECT
    'FactReviews',
    COUNT(*)
FROM dw.FactReviews

UNION ALL

SELECT
    'DimDate',
    COUNT(*)
FROM dw.DimDate

UNION ALL

SELECT
    'DimUser',
    COUNT(*)
FROM dw.DimUser

UNION ALL

SELECT
    'DimGame',
    COUNT(*)
FROM dw.DimGame

UNION ALL

SELECT
    'DimGenre',
    COUNT(*)
FROM dw.DimGenre

UNION ALL

SELECT
    'DimPaymentMethod',
    COUNT(*)
FROM dw.DimPaymentMethod

UNION ALL

SELECT
    'DimReviewRating',
    COUNT(*)
FROM dw.DimReviewRating

UNION ALL

SELECT
    'BridgeGameGenre',
    COUNT(*)
FROM dw.BridgeGameGenre;

GO
