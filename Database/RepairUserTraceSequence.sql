USE TahirFxTraderDb;
GO

/*
  Repairs the permanent user trace sequence used by sp_User_Register.
  Safe to run repeatedly on an existing database.
*/
IF COL_LENGTH(N'dbo.Users', N'UserTraceId') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD UserTraceId nvarchar(40) NULL;
END
GO

/* Backfill any account that does not yet have a trace ID. */
UPDATE dbo.Users
SET UserTraceId = N'USR-' + CONVERT(char(8), CreatedAtUtc, 112) + N'-' +
    CASE
        WHEN Id < 1000000 THEN RIGHT(N'000000' + CONVERT(nvarchar(20), Id), 6)
        ELSE CONVERT(nvarchar(20), Id)
    END
WHERE NULLIF(LTRIM(RTRIM(UserTraceId)), N'') IS NULL;
GO

DECLARE @NextTraceNumber bigint;

SELECT @NextTraceNumber = ISNULL(MAX(TraceNumber), 0) + 1
FROM
(
    SELECT TRY_CONVERT
    (
        bigint,
        RIGHT(UserTraceId, CHARINDEX(N'-', REVERSE(UserTraceId)) - 1)
    ) AS TraceNumber
    FROM dbo.Users
    WHERE UserTraceId LIKE N'USR-%-%'
      AND CHARINDEX(N'-', REVERSE(UserTraceId)) > 1
) x;

DECLARE @IdentityNext bigint = ISNULL((SELECT MAX(Id) FROM dbo.Users), 0) + 1;
IF @IdentityNext > @NextTraceNumber SET @NextTraceNumber = @IdentityNext;
IF @NextTraceNumber < 1 SET @NextTraceNumber = 1;

DECLARE @SequenceSql nvarchar(max);

IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
BEGIN
    SET @SequenceSql =
        N'CREATE SEQUENCE dbo.UserTraceReferenceSeq AS bigint START WITH ' +
        CONVERT(nvarchar(30), @NextTraceNumber) +
        N' INCREMENT BY 1 NO CYCLE;';

    EXEC sys.sp_executesql @SequenceSql;
END
ELSE
BEGIN
    DECLARE @CurrentSequenceValue bigint =
    (
        SELECT TRY_CONVERT(bigint, current_value)
        FROM sys.sequences
        WHERE object_id = OBJECT_ID(N'dbo.UserTraceReferenceSeq')
    );

    IF ISNULL(@CurrentSequenceValue + 1, 0) < @NextTraceNumber
    BEGIN
        SET @SequenceSql =
            N'ALTER SEQUENCE dbo.UserTraceReferenceSeq RESTART WITH ' +
            CONVERT(nvarchar(30), @NextTraceNumber) + N';';

        EXEC sys.sp_executesql @SequenceSql;
    END
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'UX_Users_UserTraceId'
      AND object_id = OBJECT_ID(N'dbo.Users')
)
BEGIN
    CREATE UNIQUE INDEX UX_Users_UserTraceId ON dbo.Users(UserTraceId);
END
GO

IF EXISTS(SELECT 1 FROM dbo.Users WHERE UserTraceId IS NULL)
    THROW 50011, 'One or more users do not have a trace ID.', 1;
GO

ALTER TABLE dbo.Users ALTER COLUMN UserTraceId nvarchar(40) NOT NULL;
GO

/* Recreate registration after the sequence is guaranteed to exist. */
CREATE OR ALTER PROCEDURE dbo.sp_User_Register
    @FullName nvarchar(120),
    @Country nvarchar(80),
    @PhoneNumber nvarchar(30),
    @Email nvarchar(256),
    @PasswordHash nvarchar(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Email = LOWER(LTRIM(RTRIM(@Email)));

    IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,
               N'User Trace ID sequence is missing. Run Database\\RepairUserTraceSequence.sql.' Message,
               CAST(NULL AS bigint) Id;
        RETURN;
    END

    IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email = @Email)
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,
               N'An account already exists with this email address.' Message,
               CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @RoleId int = (SELECT Id FROM dbo.Roles WHERE Name = N'User');
        DECLARE @Id bigint;
        DECLARE @TraceId nvarchar(40);
        DECLARE @TraceSequence bigint = NEXT VALUE FOR dbo.UserTraceReferenceSeq;

        SET @TraceId = N'USR-' + CONVERT(char(8), SYSUTCDATETIME(), 112) + N'-' +
            CASE
                WHEN @TraceSequence < 1000000
                    THEN RIGHT(N'000000' + CONVERT(nvarchar(20), @TraceSequence), 6)
                ELSE CONVERT(nvarchar(20), @TraceSequence)
            END;

        INSERT dbo.Users
        (
            RoleId, UserTraceId, FullName, Country, PhoneNumber, Email,
            PasswordHash, Status, IsEmailVerified, CanDeposit, CanWithdraw
        )
        VALUES
        (
            @RoleId, @TraceId, LTRIM(RTRIM(@FullName)), LTRIM(RTRIM(@Country)),
            LTRIM(RTRIM(@PhoneNumber)), @Email, @PasswordHash, 0, 0, 1, 1
        );

        SET @Id = SCOPE_IDENTITY();
        INSERT dbo.UserWallets(UserId) VALUES(@Id);

        COMMIT;

        SELECT CAST(1 AS bit) Succeeded,
               N'Account created. User ID: ' + @TraceId Message,
               @Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,
               ERROR_MESSAGE() Message,
               CAST(NULL AS bigint) Id;
    END CATCH
END
GO

SELECT
    N'dbo.UserTraceReferenceSeq' AS SequenceName,
    TRY_CONVERT(bigint, current_value) AS CurrentValue,
    TRY_CONVERT(bigint, increment) AS IncrementBy
FROM sys.sequences
WHERE object_id = OBJECT_ID(N'dbo.UserTraceReferenceSeq');
GO

PRINT 'User Trace ID sequence repaired successfully.';
GO
