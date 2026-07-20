/*
  OLX Trade - Withdrawal Email OTP Upgrade
  Adds a 2-minute email OTP challenge before a withdrawal is created.
  Safe to run more than once on an existing TahirFxTraderDb database.
*/
USE TahirFxTraderDb;
GO

IF OBJECT_ID(N'dbo.WithdrawalOtpChallenges', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.WithdrawalOtpChallenges
    (
        Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_WithdrawalOtpChallenges PRIMARY KEY,
        UserId bigint NOT NULL,
        PaymentMethodId int NOT NULL,
        WalletSource nvarchar(30) NOT NULL,
        Amount decimal(19,4) NOT NULL,
        DestinationJson nvarchar(max) NOT NULL,
        DestinationDisplay nvarchar(300) NOT NULL,
        CodeHash char(64) NOT NULL,
        ExpiresAtUtc datetime2(0) NOT NULL,
        FailedAttempts int NOT NULL CONSTRAINT DF_WithdrawalOtp_FailedAttempts DEFAULT(0),
        IsUsed bit NOT NULL CONSTRAINT DF_WithdrawalOtp_IsUsed DEFAULT(0),
        UsedAtUtc datetime2(0) NULL,
        CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_WithdrawalOtp_CreatedAt DEFAULT(SYSUTCDATETIME()),
        CONSTRAINT FK_WithdrawalOtp_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
        CONSTRAINT FK_WithdrawalOtp_Method FOREIGN KEY(PaymentMethodId) REFERENCES dbo.PaymentMethods(Id),
        CONSTRAINT CK_WithdrawalOtp_Wallet CHECK(WalletSource IN(N'Investment',N'ProfitCommission')),
        CONSTRAINT CK_WithdrawalOtp_Amount CHECK(Amount > 0),
        CONSTRAINT CK_WithdrawalOtp_Json CHECK(ISJSON(DestinationJson)=1),
        CONSTRAINT CK_WithdrawalOtp_Attempts CHECK(FailedAttempts >= 0 AND FailedAttempts <= 5)
    );
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_WithdrawalOtp_User_Active' AND object_id=OBJECT_ID(N'dbo.WithdrawalOtpChallenges'))
CREATE INDEX IX_WithdrawalOtp_User_Active ON dbo.WithdrawalOtpChallenges(UserId, IsUsed, ExpiresAtUtc DESC);
GO

CREATE OR ALTER PROCEDURE dbo.sp_WithdrawalOtp_Create
    @UserId bigint,
    @PaymentMethodId int,
    @WalletSource nvarchar(30),
    @Amount decimal(19,4),
    @DestinationJson nvarchar(max),
    @DestinationDisplay nvarchar(300),
    @CodeHash char(64),
    @ExpiresAtUtc datetime2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @WalletSource NOT IN(N'Investment',N'ProfitCommission')
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Select a valid withdrawal wallet.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF @Amount <= 0
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Enter a valid withdrawal amount.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF ISJSON(@DestinationJson) <> 1
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal destination is invalid.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF @ExpiresAtUtc <= SYSUTCDATETIME()
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'OTP expiry must be in the future.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF EXISTS
    (
        SELECT 1 FROM dbo.WithdrawalOtpChallenges
        WHERE UserId=@UserId AND IsUsed=0 AND ExpiresAtUtc>SYSUTCDATETIME()
          AND CreatedAtUtc>DATEADD(SECOND,-30,SYSUTCDATETIME())
    )
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Please wait 30 seconds before requesting another withdrawal code.' Message,CAST(NULL AS bigint) Id; RETURN; END
    DECLARE
        @CanWithdraw bit,
        @UserStatus int,
        @EmailVerified bit,
        @InvestmentBalance decimal(19,4),
        @ProfitBalance decimal(19,4),
        @CommissionBalance decimal(19,4),
        @UserMin decimal(19,4),
        @UserMax decimal(19,4),
        @UserFee decimal(9,4),
        @DefaultMin decimal(19,4),
        @DefaultMax decimal(19,4),
        @DefaultFee decimal(9,4),
        @MethodMin decimal(19,4),
        @MethodMax decimal(19,4),
        @MethodActive bit,
        @SupportsWithdrawal bit,
        @EffectiveMin decimal(19,4),
        @EffectiveMax decimal(19,4),
        @SourceBalance decimal(19,4),
        @FeePercent decimal(9,4);

    SELECT
        @CanWithdraw=u.CanWithdraw,@UserStatus=u.Status,@EmailVerified=u.IsEmailVerified,
        @UserMin=u.WithdrawalMinOverride,@UserMax=u.WithdrawalMaxOverride,@UserFee=u.WithdrawalFeePercentOverride,
        @InvestmentBalance=w.InvestmentBalance,@ProfitBalance=w.ProfitBalance,@CommissionBalance=w.CommissionBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;

    SELECT @DefaultMin=DefaultWithdrawalMin,@DefaultMax=DefaultWithdrawalMax,@DefaultFee=DefaultWithdrawalFeePercent
    FROM dbo.SystemSettings WHERE Id=1;

    SELECT @MethodMin=MinWithdrawal,@MethodMax=MaxWithdrawal,@MethodActive=IsActive,@SupportsWithdrawal=SupportsWithdrawal
    FROM dbo.PaymentMethods WHERE Id=@PaymentMethodId;

    IF ISNULL(@UserStatus,-1)<>1 OR ISNULL(@EmailVerified,0)<>1 OR ISNULL(@CanWithdraw,0)<>1
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawals are disabled for this account.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF ISNULL(@MethodActive,0)<>1 OR ISNULL(@SupportsWithdrawal,0)<>1
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'The selected withdrawal method is unavailable.' Message,CAST(NULL AS bigint) Id; RETURN; END

    SET @EffectiveMin=CASE WHEN ISNULL(@UserMin,@DefaultMin)>ISNULL(@MethodMin,0) THEN ISNULL(@UserMin,@DefaultMin) ELSE ISNULL(@MethodMin,0) END;
    SET @EffectiveMax=ISNULL(@UserMax,@DefaultMax);
    IF @MethodMax IS NOT NULL AND @MethodMax<@EffectiveMax SET @EffectiveMax=@MethodMax;

    IF @Amount<@EffectiveMin OR @Amount>@EffectiveMax
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,CAST(NULL AS bigint) Id; RETURN; END

    IF @WalletSource=N'Investment'
    BEGIN
        SET @SourceBalance=ISNULL(@InvestmentBalance,0);
        SET @FeePercent=COALESCE(@UserFee,@DefaultFee,0);
        IF @Amount-ROUND(@Amount*@FeePercent/100.0,4)<=0
        BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount must be greater than the investment withdrawal fee.' Message,CAST(NULL AS bigint) Id; RETURN; END
    END
    ELSE
    BEGIN
        SET @SourceBalance=ISNULL(@ProfitBalance,0)+ISNULL(@CommissionBalance,0);
    END

    IF @SourceBalance<@Amount
    BEGIN SELECT CAST(0 AS bit) Succeeded,CASE WHEN @WalletSource=N'Investment' THEN N'Insufficient Investment Wallet balance.' ELSE N'Insufficient combined Profit and Commission balance.' END Message,CAST(NULL AS bigint) Id; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.WithdrawalOtpChallenges
        SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId AND IsUsed=0;

        INSERT dbo.WithdrawalOtpChallenges
        (UserId,PaymentMethodId,WalletSource,Amount,DestinationJson,DestinationDisplay,CodeHash,ExpiresAtUtc)
        VALUES(@UserId,@PaymentMethodId,@WalletSource,@Amount,@DestinationJson,@DestinationDisplay,@CodeHash,@ExpiresAtUtc);
        DECLARE @Id bigint=SCOPE_IDENTITY();
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal verification code created.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_WithdrawalOtp_Get
    @Id bigint,
    @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT o.Id,o.UserId,o.PaymentMethodId,p.Name PaymentMethodName,o.WalletSource,o.Amount,o.DestinationJson,o.DestinationDisplay,
           o.ExpiresAtUtc,o.FailedAttempts,o.IsUsed,o.CreatedAtUtc
    FROM dbo.WithdrawalOtpChallenges o
    JOIN dbo.PaymentMethods p ON p.Id=o.PaymentMethodId
    WHERE o.Id=@Id AND o.UserId=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_WithdrawalOtp_Claim
    @Id bigint,
    @UserId bigint,
    @CodeHash char(64)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @StoredHash char(64),@ExpiresAtUtc datetime2(0),@IsUsed bit,@FailedAttempts int;
        SELECT @StoredHash=CodeHash,@ExpiresAtUtc=ExpiresAtUtc,@IsUsed=IsUsed,@FailedAttempts=FailedAttempts
        FROM dbo.WithdrawalOtpChallenges WITH(UPDLOCK,HOLDLOCK)
        WHERE Id=@Id AND UserId=@UserId;

        IF @StoredHash IS NULL
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal verification request not found.' Message,@Id Id; RETURN; END
        IF @IsUsed=1
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal code has already been used.' Message,@Id Id; RETURN; END
        IF @ExpiresAtUtc<=SYSUTCDATETIME()
        BEGIN
            UPDATE dbo.WithdrawalOtpChallenges SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
            COMMIT; SELECT CAST(0 AS bit) Succeeded,N'The withdrawal code has expired. Send a new code.' Message,@Id Id; RETURN;
        END
        IF @FailedAttempts>=5
        BEGIN
            UPDATE dbo.WithdrawalOtpChallenges SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
            COMMIT; SELECT CAST(0 AS bit) Succeeded,N'Too many incorrect attempts. Send a new code.' Message,@Id Id; RETURN;
        END
        IF @StoredHash<>@CodeHash
        BEGIN
            UPDATE dbo.WithdrawalOtpChallenges
            SET FailedAttempts=FailedAttempts+1,
                IsUsed=CASE WHEN FailedAttempts+1>=5 THEN 1 ELSE IsUsed END,
                UsedAtUtc=CASE WHEN FailedAttempts+1>=5 THEN SYSUTCDATETIME() ELSE UsedAtUtc END
            WHERE Id=@Id;
            COMMIT; SELECT CAST(0 AS bit) Succeeded,N'Incorrect verification code.' Message,@Id Id; RETURN;
        END

        UPDATE dbo.WithdrawalOtpChallenges SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal code verified.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_WithdrawalOtp_Cancel
    @Id bigint,
    @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.WithdrawalOtpChallenges
    SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME()
    WHERE Id=@Id AND UserId=@UserId AND IsUsed=0;
END
GO

PRINT 'Withdrawal email OTP upgrade completed.';
GO
