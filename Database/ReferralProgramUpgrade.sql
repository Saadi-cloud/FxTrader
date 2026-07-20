/*
  OLX Trade - Referral Program Upgrade
  Run this script against the same TahirFxTraderDb used by the web application.
  Safe to rerun.

  Business rules:
  - A referral relationship is created during registration from the referrer's UserTraceId.
  - The referral is counted only after the referred user's first deposit is approved.
  - Welcome bonus and referral commission are calculated once from that first deposit amount.
  - Both credits are added to ProfitBalance, not InvestmentBalance.
*/
USE TahirFxTraderDb;
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    THROW 51001, 'dbo.Users was not found. Run the base database scripts first.', 1;
END
GO
IF OBJECT_ID(N'dbo.UserWallets', N'U') IS NULL OR COL_LENGTH('dbo.UserWallets','ProfitBalance') IS NULL
BEGIN
    THROW 51002, 'Profit balance tables are missing. Run ProfitBalanceUpgrade.sql first.', 1;
END
GO
IF OBJECT_ID(N'dbo.Deposits', N'U') IS NULL
BEGIN
    THROW 51003, 'dbo.Deposits was not found. Run the base database scripts first.', 1;
END
GO

/* Admin-controlled percentages. */
IF COL_LENGTH('dbo.SystemSettings','WelcomeBonusPercent') IS NULL
    ALTER TABLE dbo.SystemSettings ADD WelcomeBonusPercent decimal(9,4) NOT NULL CONSTRAINT DF_SystemSettings_WelcomeBonus DEFAULT(0);
GO
IF COL_LENGTH('dbo.SystemSettings','ReferralCommissionPercent') IS NULL
    ALTER TABLE dbo.SystemSettings ADD ReferralCommissionPercent decimal(9,4) NOT NULL CONSTRAINT DF_SystemSettings_ReferralCommission DEFAULT(0);
GO

/* Permanent registration relationship. */
IF COL_LENGTH('dbo.Users','ReferredByUserId') IS NULL
    ALTER TABLE dbo.Users ADD ReferredByUserId bigint NULL;
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name=N'FK_Users_ReferredByUser' AND parent_object_id=OBJECT_ID(N'dbo.Users')
)
    ALTER TABLE dbo.Users WITH CHECK
    ADD CONSTRAINT FK_Users_ReferredByUser FOREIGN KEY(ReferredByUserId) REFERENCES dbo.Users(Id);
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'IX_Users_ReferredByUserId' AND object_id=OBJECT_ID(N'dbo.Users')
)
    CREATE INDEX IX_Users_ReferredByUserId ON dbo.Users(ReferredByUserId) WHERE ReferredByUserId IS NOT NULL;
GO

IF OBJECT_ID(N'dbo.WelcomeBonusReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.WelcomeBonusReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.ReferralCommissionReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.ReferralCommissionReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO

IF OBJECT_ID(N'dbo.Referrals', N'U') IS NULL
CREATE TABLE dbo.Referrals
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Referrals PRIMARY KEY,
    ReferrerUserId bigint NOT NULL,
    ReferredUserId bigint NOT NULL,
    ReferralCodeUsed nvarchar(40) NOT NULL,
    IsQualified bit NOT NULL CONSTRAINT DF_Referrals_Qualified DEFAULT(0),
    FirstDepositId bigint NULL,
    FirstDepositAmount decimal(19,4) NOT NULL CONSTRAINT DF_Referrals_FirstDepositAmount DEFAULT(0),
    WelcomeBonusPercent decimal(9,4) NOT NULL CONSTRAINT DF_Referrals_WelcomePercent DEFAULT(0),
    WelcomeBonusAmount decimal(19,4) NOT NULL CONSTRAINT DF_Referrals_WelcomeAmount DEFAULT(0),
    WelcomeBonusReferenceNo nvarchar(40) NULL,
    ReferralCommissionPercent decimal(9,4) NOT NULL CONSTRAINT DF_Referrals_CommissionPercent DEFAULT(0),
    ReferralCommissionAmount decimal(19,4) NOT NULL CONSTRAINT DF_Referrals_CommissionAmount DEFAULT(0),
    ReferralCommissionReferenceNo nvarchar(40) NULL,
    RegisteredAtUtc datetime2(0) NOT NULL CONSTRAINT DF_Referrals_Registered DEFAULT(SYSUTCDATETIME()),
    QualifiedAtUtc datetime2(0) NULL,
    CONSTRAINT UQ_Referrals_ReferredUser UNIQUE(ReferredUserId),
    CONSTRAINT FK_Referrals_Referrer FOREIGN KEY(ReferrerUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Referrals_Referred FOREIGN KEY(ReferredUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Referrals_Deposit FOREIGN KEY(FirstDepositId) REFERENCES dbo.Deposits(Id),
    CONSTRAINT CK_Referrals_DifferentUsers CHECK(ReferrerUserId<>ReferredUserId),
    CONSTRAINT CK_Referrals_Amounts CHECK(FirstDepositAmount>=0 AND WelcomeBonusAmount>=0 AND ReferralCommissionAmount>=0),
    CONSTRAINT CK_Referrals_Percentages CHECK(WelcomeBonusPercent>=0 AND WelcomeBonusPercent<=100 AND ReferralCommissionPercent>=0 AND ReferralCommissionPercent<=100)
);
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'IX_Referrals_Referrer_Qualified' AND object_id=OBJECT_ID(N'dbo.Referrals')
)
    CREATE INDEX IX_Referrals_Referrer_Qualified ON dbo.Referrals(ReferrerUserId,IsQualified,QualifiedAtUtc DESC);
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'UX_Referrals_FirstDeposit' AND object_id=OBJECT_ID(N'dbo.Referrals')
)
    CREATE UNIQUE INDEX UX_Referrals_FirstDeposit ON dbo.Referrals(FirstDepositId) WHERE FirstDepositId IS NOT NULL;
GO

IF OBJECT_ID(N'dbo.WelcomeBonuses', N'U') IS NULL
CREATE TABLE dbo.WelcomeBonuses
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_WelcomeBonuses PRIMARY KEY,
    ReferenceNo nvarchar(40) NOT NULL CONSTRAINT UQ_WelcomeBonuses_Reference UNIQUE,
    UserId bigint NOT NULL,
    DepositId bigint NOT NULL,
    DepositAmount decimal(19,4) NOT NULL,
    BonusPercent decimal(9,4) NOT NULL,
    BonusAmount decimal(19,4) NOT NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_WelcomeBonuses_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT UQ_WelcomeBonuses_Deposit UNIQUE(DepositId),
    CONSTRAINT FK_WelcomeBonuses_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_WelcomeBonuses_Deposit FOREIGN KEY(DepositId) REFERENCES dbo.Deposits(Id),
    CONSTRAINT CK_WelcomeBonuses_Values CHECK(DepositAmount>0 AND BonusPercent>0 AND BonusPercent<=100 AND BonusAmount>0)
);
GO

/* Registration supports an optional referrer UserTraceId. */
CREATE OR ALTER PROCEDURE dbo.sp_User_Register
    @FullName nvarchar(120),
    @Country nvarchar(80),
    @PhoneNumber nvarchar(30),
    @Email nvarchar(256),
    @PasswordHash nvarchar(500),
    @ReferralCode nvarchar(40)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Email=LOWER(LTRIM(RTRIM(@Email)));
    SET @ReferralCode=NULLIF(UPPER(LTRIM(RTRIM(@ReferralCode))),N'');

    IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email)
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'An account already exists with this email address.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    DECLARE @ReferrerUserId bigint=NULL;
    IF @ReferralCode IS NOT NULL
    BEGIN
        SELECT @ReferrerUserId=u.Id
        FROM dbo.Users u
        JOIN dbo.Roles r ON r.Id=u.RoleId
        WHERE u.UserTraceId=@ReferralCode AND r.Name=N'User' AND u.Status=1;

        IF @ReferrerUserId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) Succeeded,N'The referral code is invalid or the referrer account is not active.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END
    END

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=N'User');
        DECLARE @Id bigint,@TraceId nvarchar(40),@PendingTrace nvarchar(40);
        SET @PendingTrace=N'PENDING-'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'');

        INSERT dbo.Users(RoleId,UserTraceId,FullName,Country,PhoneNumber,Email,PasswordHash,Status,IsEmailVerified,CanDeposit,CanWithdraw,ReferredByUserId)
        VALUES(@RoleId,@PendingTrace,LTRIM(RTRIM(@FullName)),LTRIM(RTRIM(@Country)),LTRIM(RTRIM(@PhoneNumber)),@Email,@PasswordHash,0,0,1,1,@ReferrerUserId);

        SET @Id=SCOPE_IDENTITY();
        SET @TraceId=N'USR-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+
            CASE WHEN @Id<1000000 THEN RIGHT(N'000000'+CONVERT(nvarchar(20),@Id),6) ELSE CONVERT(nvarchar(20),@Id) END;

        UPDATE dbo.Users SET UserTraceId=@TraceId WHERE Id=@Id;
        INSERT dbo.UserWallets(UserId) VALUES(@Id);

        IF @ReferrerUserId IS NOT NULL
            INSERT dbo.Referrals(ReferrerUserId,ReferredUserId,ReferralCodeUsed)
            VALUES(@ReferrerUserId,@Id,@ReferralCode);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Account created. User ID: '+@TraceId+
               CASE WHEN @ReferrerUserId IS NULL THEN N'' ELSE N'. Referral recorded and will qualify after the first approved deposit.' END Message,
               @Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

/* First approved deposit: investment credit + one-time welcome/referral rewards. */
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Approve
    @Id bigint,
    @AdminId bigint,
    @AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Status int,@UserId bigint,@Net decimal(19,4),@Ref nvarchar(40),@Amount decimal(19,4),
                @UserBalance decimal(19,4),@InvestmentBalance decimal(19,4),@ProfitBalance decimal(19,4),@CompanyBalance decimal(19,4),
                @IsFirstApprovedDeposit bit=0;

        SELECT @Status=Status,@UserId=UserId,@Net=NetAmount,@Ref=ReferenceNo,@Amount=Amount
        FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK)
        WHERE Id=@Id;

        IF @Status IS NULL
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id;
            RETURN;
        END
        IF @Status<>0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id;
            RETURN;
        END

        /* Updating the wallet serializes approvals for the same user. */
        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance+@Net,
            InvestmentBalance=InvestmentBalance+@Net,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId;

        IF @@ROWCOUNT=0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'User wallet was not found.' Message,@Id Id;
            RETURN;
        END

        SET @IsFirstApprovedDeposit=
            CASE WHEN EXISTS(SELECT 1 FROM dbo.Deposits WHERE UserId=@UserId AND Status=2) THEN 0 ELSE 1 END;

        SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        UPDATE dbo.Deposits
        SET Status=2,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME()
        WHERE Id=@Id;

        INSERT dbo.WalletLedger
        (UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES
        (@UserId,N'DepositCredit',@Ref,N'Approved deposit added to investment',@Net,0,@UserBalance,@InvestmentBalance,@ProfitBalance,N'Deposit',@Id,1);

        UPDATE dbo.CompanyWallets
        SET Balance=Balance+@Amount,UpdatedAtUtc=SYSUTCDATETIME()
        WHERE Id=1;

        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
        VALUES(N'DepositReceipt',@Ref,N'Deposit received from user',@Amount,0,@CompanyBalance,N'Deposit',@Id);

        IF @IsFirstApprovedDeposit=1
        BEGIN
            DECLARE @WelcomePercent decimal(9,4)=0,@ReferralPercent decimal(9,4)=0,
                    @WelcomeAmount decimal(19,4)=0,@ReferralAmount decimal(19,4)=0,
                    @WelcomeReference nvarchar(40)=NULL,@ReferralReference nvarchar(40)=NULL,
                    @WelcomeBonusId bigint=NULL,@ReferralId bigint=NULL,@ReferrerUserId bigint=NULL,
                    @ReferrerBalance decimal(19,4),@ReferrerInvestment decimal(19,4),@ReferrerProfit decimal(19,4),
                    @Sequence bigint;

            SELECT @WelcomePercent=WelcomeBonusPercent,@ReferralPercent=ReferralCommissionPercent
            FROM dbo.SystemSettings WITH(HOLDLOCK)
            WHERE Id=1;

            SET @WelcomeAmount=ROUND(@Amount*@WelcomePercent/100.0,4);

            IF @WelcomeAmount>0
            BEGIN
                SET @Sequence=NEXT VALUE FOR dbo.WelcomeBonusReferenceSeq;
                SET @WelcomeReference=N'WLB-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Sequence),6);

                INSERT dbo.WelcomeBonuses(ReferenceNo,UserId,DepositId,DepositAmount,BonusPercent,BonusAmount)
                VALUES(@WelcomeReference,@UserId,@Id,@Amount,@WelcomePercent,@WelcomeAmount);
                SET @WelcomeBonusId=SCOPE_IDENTITY();

                UPDATE dbo.UserWallets
                SET ProfitBalance=ProfitBalance+@WelcomeAmount,
                    AvailableBalance=AvailableBalance+@WelcomeAmount,
                    UpdatedAtUtc=SYSUTCDATETIME()
                WHERE UserId=@UserId;

                SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance
                FROM dbo.UserWallets WHERE UserId=@UserId;

                INSERT dbo.WalletLedger
                (UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
                VALUES
                (@UserId,N'WelcomeBonus',@WelcomeReference,N'Welcome bonus on first approved deposit',@WelcomeAmount,0,@UserBalance,@InvestmentBalance,@ProfitBalance,N'WelcomeBonus',@WelcomeBonusId,1);
            END

            SELECT @ReferralId=Id,@ReferrerUserId=ReferrerUserId
            FROM dbo.Referrals WITH(UPDLOCK,HOLDLOCK)
            WHERE ReferredUserId=@UserId AND IsQualified=0;

            IF @ReferralId IS NOT NULL
            BEGIN
                SET @ReferralAmount=ROUND(@Amount*@ReferralPercent/100.0,4);

                IF @ReferralAmount>0
                BEGIN
                    SET @Sequence=NEXT VALUE FOR dbo.ReferralCommissionReferenceSeq;
                    SET @ReferralReference=N'RFC-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Sequence),6);

                    UPDATE dbo.UserWallets
                    SET ProfitBalance=ProfitBalance+@ReferralAmount,
                        AvailableBalance=AvailableBalance+@ReferralAmount,
                        UpdatedAtUtc=SYSUTCDATETIME()
                    WHERE UserId=@ReferrerUserId;

                    IF @@ROWCOUNT=0
                    BEGIN
                        ROLLBACK;
                        SELECT CAST(0 AS bit) Succeeded,N'Referrer wallet was not found. No deposit changes were committed.' Message,@Id Id;
                        RETURN;
                    END

                    SELECT @ReferrerBalance=AvailableBalance,@ReferrerInvestment=InvestmentBalance,@ReferrerProfit=ProfitBalance
                    FROM dbo.UserWallets WHERE UserId=@ReferrerUserId;

                    INSERT dbo.WalletLedger
                    (UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
                    VALUES
                    (@ReferrerUserId,N'ReferralCommission',@ReferralReference,N'Referral commission after referred user first deposit',@ReferralAmount,0,@ReferrerBalance,@ReferrerInvestment,@ReferrerProfit,N'Referral',@ReferralId,1);
                END

                UPDATE dbo.Referrals
                SET IsQualified=1,
                    FirstDepositId=@Id,
                    FirstDepositAmount=@Amount,
                    WelcomeBonusPercent=@WelcomePercent,
                    WelcomeBonusAmount=@WelcomeAmount,
                    WelcomeBonusReferenceNo=@WelcomeReference,
                    ReferralCommissionPercent=@ReferralPercent,
                    ReferralCommissionAmount=@ReferralAmount,
                    ReferralCommissionReferenceNo=@ReferralReference,
                    QualifiedAtUtc=SYSUTCDATETIME()
                WHERE Id=@ReferralId;
            END
        END

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'Deposit.Approve',N'Deposit',CONVERT(nvarchar(60),@Id),
               COALESCE(@AdminNote,N'')+CASE WHEN @IsFirstApprovedDeposit=1 THEN N'; First deposit rewards evaluated.' ELSE N'' END);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Deposit approved and added to user investment balance.'+
               CASE WHEN @IsFirstApprovedDeposit=1 THEN N' First-deposit welcome and referral rewards were applied according to current settings.' ELSE N'' END Message,
               @Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

/* User dashboard includes qualified referral count and total commission earned. */
CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.FullName,u.UserTraceId,w.AvailableBalance,w.HeldBalance,w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,
           ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
           ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
           (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
           (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals,
           (SELECT COUNT(*) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1) SuccessfulReferralCount,
           ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1),0) ReferralCommissionEarned
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;

    SELECT TOP(10) Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ReferralDashboard_Get
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.WelcomeBonusPercent,s.ReferralCommissionPercent,
           (SELECT COUNT(*) FROM dbo.Referrals) RegisteredReferralCount,
           (SELECT COUNT(*) FROM dbo.Referrals WHERE IsQualified=1) QualifiedReferralCount,
           ISNULL((SELECT SUM(BonusAmount) FROM dbo.WelcomeBonuses),0) TotalWelcomeBonusPaid,
           ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE IsQualified=1),0) TotalReferralCommissionPaid
    FROM dbo.SystemSettings s
    WHERE s.Id=1;

    SELECT TOP(250)
           rf.Id,
           referrer.UserTraceId ReferrerTraceId,
           referrer.FullName ReferrerName,
           referred.UserTraceId ReferredTraceId,
           referred.FullName ReferredName,
           rf.IsQualified,
           rf.FirstDepositAmount,
           rf.WelcomeBonusAmount,
           rf.ReferralCommissionAmount,
           rf.RegisteredAtUtc,
           rf.QualifiedAtUtc
    FROM dbo.Referrals rf
    JOIN dbo.Users referrer ON referrer.Id=rf.ReferrerUserId
    JOIN dbo.Users referred ON referred.Id=rf.ReferredUserId
    ORDER BY rf.RegisteredAtUtc DESC,rf.Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_WelcomeBonusSettings_Save
    @Percentage decimal(9,4),
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    IF @Percentage<0 OR @Percentage>100
    BEGIN
        THROW 51004, 'Welcome bonus percentage must be between 0 and 100.', 1;
    END

    UPDATE dbo.SystemSettings
    SET WelcomeBonusPercent=@Percentage,UpdatedAtUtc=SYSUTCDATETIME(),UpdatedBy=@AdminId
    WHERE Id=1;

    INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
    VALUES(@AdminId,N'Referral.WelcomeBonus.Update',N'SystemSettings',N'1',N'WelcomeBonusPercent='+CONVERT(nvarchar(30),@Percentage));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ReferralCommissionSettings_Save
    @Percentage decimal(9,4),
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    IF @Percentage<0 OR @Percentage>100
    BEGIN
        THROW 51005, 'Referral commission percentage must be between 0 and 100.', 1;
    END

    UPDATE dbo.SystemSettings
    SET ReferralCommissionPercent=@Percentage,UpdatedAtUtc=SYSUTCDATETIME(),UpdatedBy=@AdminId
    WHERE Id=1;

    INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
    VALUES(@AdminId,N'Referral.Commission.Update',N'SystemSettings',N'1',N'ReferralCommissionPercent='+CONVERT(nvarchar(30),@Percentage));
END
GO

PRINT 'Referral program upgrade completed successfully.';
GO
