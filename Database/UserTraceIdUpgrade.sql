USE TahirFxTraderDb;
GO


/* Ensure the sequence exists before any registration procedure is created. */
IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
BEGIN
    DECLARE @UserTraceStart bigint = ISNULL((SELECT MAX(Id) FROM dbo.Users), 0) + 1;
    DECLARE @UserTraceSql nvarchar(max);
    IF @UserTraceStart < 1 SET @UserTraceStart = 1;
    SET @UserTraceSql = N'CREATE SEQUENCE dbo.UserTraceReferenceSeq AS bigint START WITH ' +
                        CONVERT(nvarchar(30), @UserTraceStart) +
                        N' INCREMENT BY 1 NO CYCLE;';
    EXEC sys.sp_executesql @UserTraceSql;
END
GO

/* Permanent user trace ID, e.g. USR-20260715-000001 */
IF COL_LENGTH('dbo.Users','UserTraceId') IS NULL
    ALTER TABLE dbo.Users ADD UserTraceId nvarchar(40) NULL;
GO

UPDATE dbo.Users
SET UserTraceId = N'USR-' + CONVERT(char(8), CreatedAtUtc, 112) + N'-' +
    CASE
        WHEN Id < 1000000 THEN RIGHT(N'000000' + CONVERT(nvarchar(20), Id), 6)
        ELSE CONVERT(nvarchar(20), Id)
    END
WHERE NULLIF(LTRIM(RTRIM(UserTraceId)), N'') IS NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = N'UX_Users_UserTraceId' AND object_id = OBJECT_ID(N'dbo.Users')
)
    CREATE UNIQUE INDEX UX_Users_UserTraceId ON dbo.Users(UserTraceId);
GO

ALTER TABLE dbo.Users ALTER COLUMN UserTraceId nvarchar(40) NOT NULL;
GO

IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
BEGIN
    DECLARE @UserTraceStart bigint = ISNULL((SELECT MAX(Id) FROM dbo.Users),0) + 1;
    DECLARE @UserTraceSql nvarchar(max);
    SET @UserTraceSql = N'CREATE SEQUENCE dbo.UserTraceReferenceSeq AS bigint START WITH ' +
                        CONVERT(nvarchar(30), @UserTraceStart) +
                        N' INCREMENT BY 1 NO CYCLE;';
    EXEC sys.sp_executesql @UserTraceSql;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetByEmail @Email nvarchar(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Email=LOWER(LTRIM(RTRIM(@Email)));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetById @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

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
    SET @Email=LOWER(LTRIM(RTRIM(@Email)));

    IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'User Trace ID sequence is missing. Run Database\RepairUserTraceSequence.sql.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email)
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'An account already exists with this email address.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=N'User');
        DECLARE @Id bigint,@TraceId nvarchar(40),@TraceSequence bigint;
        SET @TraceSequence=NEXT VALUE FOR dbo.UserTraceReferenceSeq;

        SET @TraceId=N'USR-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+
            CASE WHEN @TraceSequence<1000000 THEN RIGHT(N'000000'+CONVERT(nvarchar(20),@TraceSequence),6) ELSE CONVERT(nvarchar(20),@TraceSequence) END;

        INSERT dbo.Users(RoleId,UserTraceId,FullName,Country,PhoneNumber,Email,PasswordHash,Status,IsEmailVerified,CanDeposit,CanWithdraw)
        VALUES(@RoleId,@TraceId,LTRIM(RTRIM(@FullName)),LTRIM(RTRIM(@Country)),LTRIM(RTRIM(@PhoneNumber)),@Email,@PasswordHash,0,0,1,1);

        SET @Id=SCOPE_IDENTITY();
        INSERT dbo.UserWallets(UserId) VALUES(@Id);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Account created. User ID: '+@TraceId Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Users_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    ORDER BY u.CreatedAtUtc DESC,u.Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride
    FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId WHERE u.Id=@UserId;

    SELECT p.PermissionKey,CAST(ISNULL(o.IsAllowed,CASE WHEN rp.PermissionId IS NULL THEN 0 ELSE 1 END) AS bit) IsAllowed
    FROM dbo.Permissions p
    CROSS JOIN dbo.Users u
    LEFT JOIN dbo.RolePermissions rp ON rp.RoleId=u.RoleId AND rp.PermissionId=p.Id
    LEFT JOIN dbo.UserPermissionOverrides o ON o.UserId=u.Id AND o.PermissionId=p.Id
    WHERE u.Id=@UserId ORDER BY p.PermissionKey;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_GetByTraceId @UserTraceId nvarchar(40)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.UserTraceId=UPPER(LTRIM(RTRIM(@UserTraceId)));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalances_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    JOIN dbo.Roles r ON r.Id=u.RoleId
    WHERE r.Name=N'User'
    ORDER BY u.FullName,u.Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalance_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.FullName,u.UserTraceId,w.AvailableBalance,w.HeldBalance,w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,
           ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
           ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
           (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
           (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals
    FROM dbo.Users u JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Id=@UserId;

    SELECT TOP(10) Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Deposits_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.Id,d.ReferenceNo,d.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,
           d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
    FROM dbo.Deposits d
    JOIN dbo.Users u ON u.Id=d.UserId
    JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId
    WHERE d.UserId=@UserId ORDER BY d.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposits_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.Id,d.ReferenceNo,d.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,
           d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
    FROM dbo.Deposits d
    JOIN dbo.Users u ON u.Id=d.UserId
    JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId
    ORDER BY CASE WHEN d.Status=0 THEN 0 ELSE 1 END,d.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.Id,d.ReferenceNo,d.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,
           d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
    FROM dbo.Deposits d
    JOIN dbo.Users u ON u.Id=d.UserId
    JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId
    WHERE d.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.UserId=@UserId ORDER BY w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    ORDER BY CASE WHEN w.Status IN(0,1) THEN 0 ELSE 1 END,w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.Id=@Id;
END
GO

PRINT 'User trace ID upgrade completed.';
GO
