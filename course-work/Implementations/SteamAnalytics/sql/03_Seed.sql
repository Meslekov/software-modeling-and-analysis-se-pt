USE SteamAnalytics;
GO

SET NOCOUNT ON;


/* Run once against a new database. Realistic but synthetic coursework data. */

INSERT dbo.Genres(Name, Description)
VALUES
    ('Action', 'Fast-paced games'),
    ('Adventure', 'Exploration and stories'),
    ('RPG', 'Character progression'),
    ('Strategy', 'Planning and tactics'),
    ('Simulation', 'Simulated systems'),
    ('Puzzle', 'Problem solving');


INSERT dbo.Games(Title, Description, Price, ReleaseDate)
VALUES
    ('Neon Horizon', 'Cyberpunk action', 29.99, '2023-02-12'),
    ('Forest Keeper', 'Nature adventure', 14.99, '2022-04-10'),
    ('Iron Tactics', 'Turn-based strategy', 19.50, '2021-06-20'),
    ('Starlight Odyssey', 'Space RPG', 39.99, '2024-05-16'),
    ('Puzzle Circuit', 'Logic puzzles', 9.99, '2020-07-30'),
    ('City Architect', 'City simulation', 24.99, '2023-11-02'),
    ('Dragon Vale', 'Fantasy adventure', 34.99, '2022-09-15'),
    ('Orbit Commander', 'Space strategy', 17.99, '2024-01-23'),
    ('Farm Seasons', 'Farming simulator', 12.49, '2021-03-09'),
    ('Shadow Protocol', 'Stealth action', 27.99, '2024-08-19'),
    ('Mystic Ruins', 'Puzzle adventure', 16.99, '2020-12-11'),
    ('Arena Nova', 'Competitive action', 0.00, '2025-02-01');


INSERT dbo.GameGenres(GameId, GenreId)
VALUES
    (1, 1),
    (1, 2),
    (2, 2),
    (3, 4),
    (4, 3),
    (4, 2),
    (5, 6),
    (6, 5),
    (7, 3),
    (7, 2),
    (8, 4),
    (8, 1),
    (9, 5),
    (10, 1),
    (10, 4),
    (11, 6),
    (11, 2),
    (12, 1);


;WITH nums AS (
    SELECT 1 AS n

    UNION ALL

    SELECT n + 1
    FROM nums
    WHERE n < 30
)
INSERT dbo.Users(Username, Email, Country, CreatedAt)
SELECT
    CONCAT('player', RIGHT(CONCAT('000', n), 3)),
    CONCAT('player', RIGHT(CONCAT('000', n), 3), '@example.test'),
    CASE n % 4
        WHEN 0 THEN 'Bulgaria'
        WHEN 1 THEN 'Germany'
        WHEN 2 THEN 'France'
        ELSE 'Poland'
    END,
    DATEADD(
        DAY,
        -n * 10,
        CAST('2026-10-01' AS DATETIME2(0))
    )
FROM nums
OPTION (MAXRECURSION 0);


/* For each player buy 3 distinct games; every fifth payment fails. */

DECLARE
    @u INT = 1,
    @j INT,
    @g INT,
    @p INT,
    @success BIT;

WHILE @u <= 30
BEGIN
    SET @j = 0;

    WHILE @j < 3
    BEGIN
        SET @g = ((@u + @j * 4 - 1) % 12) + 1;

        EXEC dbo.usp_CreatePurchase
            @UserId = @u,
            @GameId = @g,
            @PurchaseId = @p OUTPUT;

        SET @success = CASE
            WHEN (@u + @j) % 5 = 0 THEN 0
            ELSE 1
        END;

        EXEC dbo.usp_CompletePayment
            @PurchaseId = @p,
            @Method = 'Card',
            @Succeeded = @success;

        /* Spread synthetic purchases across a year; purchase price remains unchanged. */

        UPDATE dbo.Purchases
        SET PurchaseDate = DATEADD(
            DAY,
            -((@u * 11 + @j * 29) % 350),
            CAST('2026-10-01' AS DATETIME2(0))
        )
        WHERE PurchaseId = @p;

        SET @j = @j + 1;
    END;

    SET @u = @u + 1;
END;


/* 3 completed sessions per owned game. */

INSERT dbo.GameplaySessions(LibraryEntryId, StartedAt, EndedAt)
SELECT
    l.LibraryEntryId,
    DATEADD(
        DAY,
        -((l.LibraryEntryId * 7 + x.n * 17) % 150),
        CAST('2026-09-30T18:00:00' AS DATETIME2(0))
    ),
    DATEADD(
        MINUTE,
        30 + ((l.LibraryEntryId * 13 + x.n * 23) % 150),
        DATEADD(
            DAY,
            -((l.LibraryEntryId * 7 + x.n * 17) % 150),
            CAST('2026-09-30T18:00:00' AS DATETIME2(0))
        )
    )
FROM dbo.LibraryEntries l
CROSS JOIN (VALUES (1), (2), (3)) x(n);


/* One review for every second owned game. */

INSERT dbo.Reviews(UserId, GameId, Rating, Comment, CreatedAt)
SELECT
    l.UserId,
    l.GameId,
    CAST(1 + (l.LibraryEntryId % 5) AS TINYINT),
    'Synthetic coursework review',
    CAST('2026-10-01' AS DATETIME2(0))
FROM dbo.LibraryEntries l
WHERE l.LibraryEntryId % 2 = 0;


SELECT
    'Users' AS Entity,
    COUNT(*) AS RowsCount
FROM dbo.Users

UNION ALL

SELECT
    'Games',
    COUNT(*)
FROM dbo.Games

UNION ALL

SELECT
    'Genres',
    COUNT(*)
FROM dbo.Genres

UNION ALL

SELECT
    'GameGenres',
    COUNT(*)
FROM dbo.GameGenres

UNION ALL

SELECT
    'Purchases',
    COUNT(*)
FROM dbo.Purchases

UNION ALL

SELECT
    'PurchaseItems',
    COUNT(*)
FROM dbo.PurchaseItems

UNION ALL

SELECT
    'Payments',
    COUNT(*)
FROM dbo.Payments

UNION ALL

SELECT
    'LibraryEntries',
    COUNT(*)
FROM dbo.LibraryEntries

UNION ALL

SELECT
    'GameplaySessions',
    COUNT(*)
FROM dbo.GameplaySessions

UNION ALL

SELECT
    'Reviews',
    COUNT(*)
FROM dbo.Reviews;

GO
