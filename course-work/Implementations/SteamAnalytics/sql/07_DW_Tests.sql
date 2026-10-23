USE SteamAnalytics;
GO


/* Every Issues result must be zero. */

SELECT
    'Sales row count mismatch' AS Test,
    ABS(
        (SELECT COUNT(*) FROM dw.FactSales)
        -
        (
            SELECT COUNT(*)
            FROM dbo.PurchaseItems pi
            JOIN dbo.Purchases p
                ON p.PurchaseId = pi.PurchaseId
            WHERE p.Status = 'Completed'
        )
    ) AS Issues

UNION ALL

SELECT
    'Sales revenue mismatch (cents)',
    CAST(
        ABS(
            (
                SELECT COALESCE(SUM(Revenue), 0)
                FROM dw.FactSales
            )
            -
            (
                SELECT COALESCE(SUM(pi.UnitPrice), 0)
                FROM dbo.PurchaseItems pi
                JOIN dbo.Purchases p
                    ON p.PurchaseId = pi.PurchaseId
                WHERE p.Status = 'Completed'
            )
        ) * 100
        AS BIGINT
    )

UNION ALL

SELECT
    'Gameplay row count mismatch',
    ABS(
        (SELECT COUNT(*) FROM dw.FactGameplay)
        -
        (SELECT COUNT(*) FROM dbo.GameplaySessions)
    )

UNION ALL

SELECT
    'Reviews row count mismatch',
    ABS(
        (SELECT COUNT(*) FROM dw.FactReviews)
        -
        (SELECT COUNT(*) FROM dbo.Reviews)
    )

UNION ALL

SELECT
    'Games without genres in bridge',
    COUNT(*)
FROM dw.DimGame g
WHERE NOT EXISTS (
    SELECT 1
    FROM dw.BridgeGameGenre b
    WHERE b.GameKey = g.GameKey
)

UNION ALL

SELECT
    'Bridge weights not approximately one',
    COUNT(*)
FROM (
    SELECT
        GameKey
    FROM dw.BridgeGameGenre
    GROUP BY GameKey
    HAVING ABS(SUM(GenreWeight) - 1.0) > 0.00001
) v;

GO


/* Safe totals for Power BI. Genre requires weighted measures; see reporting guide. */

SELECT
    COUNT(*) AS CompletedPurchaseItems,
    SUM(Revenue) AS TotalRevenue
FROM dw.FactSales;


SELECT
    COUNT(*) AS GameplaySessions,
    SUM(DurationMinutes) AS TotalPlaytimeMinutes
FROM dw.FactGameplay;


SELECT
    COUNT(*) AS Reviews,
    CAST(
        AVG(CAST(RatingKey AS DECIMAL(9,2)))
        AS DECIMAL(9,2)
    ) AS AvgRating
FROM dw.FactReviews;

GO
