USE SteamAnalytics;
GO


/* 2 functions */

CREATE OR ALTER FUNCTION dbo.fn_GetUserTotalPlaytime(@UserId INT)
RETURNS BIGINT
AS
BEGIN
    DECLARE @Minutes BIGINT;

    SELECT
        @Minutes = COALESCE(
            SUM(DATEDIFF_BIG(SECOND, s.StartedAt, s.EndedAt) / 60),
            0
        )
    FROM dbo.GameplaySessions s
    INNER JOIN dbo.LibraryEntries l
        ON s.LibraryEntryId = l.LibraryEntryId
    WHERE l.UserId = @UserId;

    RETURN @Minutes;
END;
GO


CREATE OR ALTER FUNCTION dbo.fn_GetGameRevenue(@GameId INT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @Revenue DECIMAL(18,2);

    SELECT
        @Revenue = COALESCE(
            SUM(CAST(i.UnitPrice AS DECIMAL(18,2))),
            0
        )
    FROM dbo.PurchaseItems i
    INNER JOIN dbo.Purchases p
        ON p.PurchaseId = i.PurchaseId
    WHERE i.GameId = @GameId
        AND p.Status = 'Completed';

    RETURN @Revenue;
END;
GO


/* Trigger 1: completing payment grants ownership; set-based for multi-row INSERT/UPDATE. */

CREATE OR ALTER TRIGGER dbo.trg_Payments_GrantOwnership
ON dbo.Payments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Purchases p
            ON p.PurchaseId = i.PurchaseId
        WHERE i.Status = 'Completed'
            AND (
                i.Amount <> p.TotalAmount
                OR
                NOT EXISTS (
                    SELECT 1
                    FROM dbo.PurchaseItems x
                    WHERE x.PurchaseId = i.PurchaseId
                )
                OR
                p.TotalAmount <> (
                    SELECT COALESCE(SUM(x.UnitPrice), 0)
                    FROM dbo.PurchaseItems x
                    WHERE x.PurchaseId = i.PurchaseId
                )
            )
    )
        THROW 51001, 'Completed payment requires nonempty purchase items and an exact matching total.', 1;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Purchases p
            ON p.PurchaseId = i.PurchaseId
        WHERE p.Status = 'Completed'
            AND i.Status <> 'Completed'
    )
        THROW 51002, 'Completed purchases cannot have their payment reversed in this simplified project.', 1;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.PurchaseItems x
            ON x.PurchaseId = i.PurchaseId
        JOIN dbo.LibraryEntries l
            ON l.UserId = (
                SELECT p.UserId
                FROM dbo.Purchases p
                WHERE p.PurchaseId = i.PurchaseId
            )
            AND l.GameId = x.GameId
        WHERE i.Status = 'Completed'
            AND NOT EXISTS (
                SELECT 1
                FROM deleted d
                WHERE d.PaymentId = i.PaymentId
                    AND d.Status = 'Completed'
            )
    )
        THROW 51003, 'The user already owns a game in this purchase.', 1;

    UPDATE p
    SET p.Status = i.Status
    FROM dbo.Purchases p
    JOIN inserted i
        ON p.PurchaseId = i.PurchaseId;

    INSERT dbo.LibraryEntries(UserId, GameId, AddedAt)
    SELECT
        p.UserId,
        x.GameId,
        COALESCE(i.PaidAt, p.PurchaseDate)
    FROM inserted i
    JOIN dbo.Purchases p
        ON p.PurchaseId = i.PurchaseId
    JOIN dbo.PurchaseItems x
        ON x.PurchaseId = i.PurchaseId
    WHERE i.Status = 'Completed'
        AND NOT EXISTS (
            SELECT 1
            FROM deleted d
            WHERE d.PaymentId = i.PaymentId
                AND d.Status = 'Completed'
        );
END;
GO


/* Trigger 2: audit changes, including multi-row changes and deletes. */

CREATE OR ALTER TRIGGER dbo.trg_Reviews_Audit
ON dbo.Reviews
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.ReviewAudit(ReviewId, ActionType, OldRating, NewRating)
    SELECT
        COALESCE(i.ReviewId, d.ReviewId),
        CASE
            WHEN i.ReviewId IS NULL THEN 'DELETE'
            WHEN d.ReviewId IS NULL THEN 'INSERT'
            ELSE 'UPDATE'
        END,
        d.Rating,
        i.Rating
    FROM inserted i
    FULL OUTER JOIN deleted d
        ON i.ReviewId = d.ReviewId;
END;
GO


/* Procedure 1: create a pending one-game purchase. Repeat purchases use different games. */

CREATE OR ALTER PROCEDURE dbo.usp_CreatePurchase
    @UserId INT,
    @GameId INT,
    @PurchaseId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Users
            WHERE UserId = @UserId
        )
            THROW 51011, 'Unknown user.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Games
            WHERE GameId = @GameId
        )
            THROW 51012, 'Unknown game.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.LibraryEntries WITH (UPDLOCK, HOLDLOCK)
            WHERE UserId = @UserId
                AND GameId = @GameId
        )
            THROW 51013, 'Game is already owned.', 1;

        DECLARE @Price DECIMAL(12,2);

        SELECT
            @Price = Price
        FROM dbo.Games
        WHERE GameId = @GameId;

        INSERT dbo.Purchases(UserId, Status, TotalAmount)
        VALUES (@UserId, 'Pending', @Price);

        SET @PurchaseId = CONVERT(INT, SCOPE_IDENTITY());

        INSERT dbo.PurchaseItems(PurchaseId, GameId, UnitPrice)
        VALUES (@PurchaseId, @GameId, @Price);

        COMMIT;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;
    END CATCH;
END;
GO


/* Procedure 2: close payment; trigger performs library synchronization. */

CREATE OR ALTER PROCEDURE dbo.usp_CompletePayment
    @PurchaseId INT,
    @Method VARCHAR(20),
    @Succeeded BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE
            @Amount DECIMAL(12,2),
            @Status VARCHAR(12);

        SELECT
            @Amount = TotalAmount,
            @Status = Status
        FROM dbo.Purchases WITH (UPDLOCK, HOLDLOCK)
        WHERE PurchaseId = @PurchaseId;

        IF @Status IS NULL
            THROW 51021, 'Unknown purchase.', 1;

        IF @Status <> 'Pending'
            THROW 51022, 'Only pending purchases can be paid.', 1;

        IF @Method NOT IN ('Card', 'PayPal', 'Bank')
            OR @Method IS NULL
            THROW 51023, 'Unsupported payment method.', 1;

        INSERT dbo.Payments(PurchaseId, Amount, Method, Status, PaidAt)
        VALUES (
            @PurchaseId,
            @Amount,
            @Method,
            CASE
                WHEN @Succeeded = 1 THEN 'Completed'
                ELSE 'Failed'
            END,
            CASE
                WHEN @Succeeded = 1 THEN SYSUTCDATETIME()
                ELSE NULL
            END
        );

        COMMIT;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;
    END CATCH;
END;
GO


PRINT '02_Logic completed: 2 functions, 2 triggers, 2 procedures';
