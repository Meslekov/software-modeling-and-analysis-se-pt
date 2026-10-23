USE SteamAnalytics;
GO


/* Read-only checks: all counts should be 0 unless noted. */

SELECT
    'Completed purchase without ownership' AS Test,
    COUNT(*) AS Issues
FROM dbo.Purchases p
JOIN dbo.PurchaseItems pi
    ON p.PurchaseId = pi.PurchaseId
WHERE p.Status = 'Completed'
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.LibraryEntries l
        WHERE l.UserId = p.UserId
            AND l.GameId = pi.GameId
    )

UNION ALL

SELECT
    'Unpaid ownership',
    COUNT(*)
FROM dbo.LibraryEntries l
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.Purchases p
    JOIN dbo.PurchaseItems pi
        ON p.PurchaseId = pi.PurchaseId
    WHERE p.UserId = l.UserId
        AND pi.GameId = l.GameId
        AND p.Status = 'Completed'
)

UNION ALL

SELECT
    'Invalid completed purchase amount',
    COUNT(*)
FROM dbo.Purchases p
WHERE p.Status = 'Completed'
    AND p.TotalAmount <> (
        SELECT COALESCE(SUM(i.UnitPrice), 0)
        FROM dbo.PurchaseItems i
        WHERE i.PurchaseId = p.PurchaseId
    )

UNION ALL

SELECT
    'Reviews without ownership',
    COUNT(*)
FROM dbo.Reviews r
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.LibraryEntries l
    WHERE l.UserId = r.UserId
        AND l.GameId = r.GameId
);


SELECT
    p.Status,
    COUNT(*) AS Purchases,
    SUM(p.TotalAmount) AS PurchaseTotal
FROM dbo.Purchases p
GROUP BY p.Status;


SELECT TOP (5)
    g.Title,
    dbo.fn_GetGameRevenue(g.GameId) AS Revenue
FROM dbo.Games g
ORDER BY Revenue DESC;


SELECT TOP (5)
    u.Username,
    dbo.fn_GetUserTotalPlaytime(u.UserId) AS PlaytimeMinutes
FROM dbo.Users u
ORDER BY PlaytimeMinutes DESC;


SELECT
    COUNT(*) AS AuditRows
FROM dbo.ReviewAudit;

GO
