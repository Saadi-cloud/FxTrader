/*
  OLX Trade - Compound Profit + Separate Commission Wallet Upgrade
  Safe to rerun on TahirFxTraderDb after the referral/profit upgrades.

  Rules:
  - Profit base = available InvestmentBalance + available ProfitBalance.
  - CommissionBalance is excluded from profit compounding.
  - Referral commission is credited to CommissionBalance.
  - Welcome bonus remains in ProfitBalance.
  - Withdrawals consume Profit first, then Commission, then Investment.
*/
USE TahirFxTraderDb;
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL OR OBJECT_ID(N'dbo.UserWallets', N'U') IS NULL
BEGIN
    THROW 52001, 'Base user and wallet tables are missing.', 1;
END
GO
IF COL_LENGTH(N'dbo.UserWallets', N'InvestmentBalance') IS NULL OR COL_LENGTH(N'dbo.UserWallets', N'ProfitBalance') IS NULL
BEGIN
    THROW 52002, 'Run ProfitBalanceUpgrade.sql before this script.', 1;
END
GO
IF OBJECT_ID(N'dbo.Referrals', N'U') IS NULL
BEGIN
    THROW 52003, 'Run ReferralProgramUpgrade.sql before this script.', 1;
END
GO
IF OBJECT_ID(N'dbo.ProfitAllocations', N'U') IS NULL
CREATE TABLE dbo.ProfitAllocations
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProfitAllocations PRIMARY KEY,
    ReferenceNo nvarchar(40) NOT NULL CONSTRAINT UQ_ProfitAllocations_Reference UNIQUE,
    UserId bigint NOT NULL,
    InvestmentBase decimal(19,4) NOT NULL,
    ProfitPercentage decimal(9,4) NOT NULL,
    ProfitAmount decimal(19,4) NOT NULL,
    AdminNote nvarchar(500) NULL,
    AddedBy bigint NOT NULL,
    BatchId bigint NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ProfitAllocations_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_ProfitAllocations_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_ProfitAllocations_Admin FOREIGN KEY(AddedBy) REFERENCES dbo.Users(Id)
);
GO
IF OBJECT_ID(N'dbo.ProfitBatches', N'U') IS NULL
CREATE TABLE dbo.ProfitBatches
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProfitBatches PRIMARY KEY,
    BatchReference nvarchar(40) NOT NULL CONSTRAINT UQ_ProfitBatches_Reference UNIQUE,
    ProfitPercentage decimal(9,4) NOT NULL,
    EligibleUserCount int NOT NULL,
    TotalInvestmentBase decimal(38,4) NOT NULL,
    TotalProfitAmount decimal(38,4) NOT NULL,
    AdminNote nvarchar(500) NULL,
    AddedBy bigint NOT NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ProfitBatches_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_ProfitBatches_Admin FOREIGN KEY(AddedBy) REFERENCES dbo.Users(Id)
);
GO
IF COL_LENGTH(N'dbo.ProfitAllocations',N'BatchId') IS NULL
    ALTER TABLE dbo.ProfitAllocations ADD BatchId bigint NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_ProfitAllocations_Batch' AND parent_object_id=OBJECT_ID(N'dbo.ProfitAllocations'))
    ALTER TABLE dbo.ProfitAllocations ADD CONSTRAINT FK_ProfitAllocations_Batch FOREIGN KEY(BatchId) REFERENCES dbo.ProfitBatches(Id);
GO
IF OBJECT_ID(N'dbo.ProfitReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.ProfitReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.ProfitBatchReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.ProfitBatchReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.WelcomeBonusReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.WelcomeBonusReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.ReferralCommissionReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.ReferralCommissionReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO

IF COL_LENGTH(N'dbo.UserWallets', N'CommissionBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD CommissionBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_Commission DEFAULT(0);
GO
IF COL_LENGTH(N'dbo.UserWallets', N'HeldCommissionBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD HeldCommissionBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_HeldCommission DEFAULT(0);
GO
IF COL_LENGTH(N'dbo.Withdrawals', N'CommissionAmount') IS NULL
    ALTER TABLE dbo.Withdrawals ADD CommissionAmount decimal(19,4) NOT NULL CONSTRAINT DF_Withdrawals_CommissionAmount DEFAULT(0);
GO
IF COL_LENGTH(N'dbo.WalletLedger', N'CommissionBalanceAfter') IS NULL
    ALTER TABLE dbo.WalletLedger ADD CommissionBalanceAfter decimal(19,4) NOT NULL CONSTRAINT DF_Ledger_CommissionAfter DEFAULT(0);
GO

IF OBJECT_ID(N'dbo.ApplicationMigrations', N'U') IS NULL
CREATE TABLE dbo.ApplicationMigrations
(
    MigrationKey nvarchar(150) NOT NULL CONSTRAINT PK_ApplicationMigrations PRIMARY KEY,
    AppliedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ApplicationMigrations_Applied DEFAULT(SYSUTCDATETIME())
);
GO

/* Existing historical balances are not reclassified automatically because prior withdrawals
   did not preserve the source of each profit credit. New referral commissions use CommissionBalance. */
IF NOT EXISTS(SELECT 1 FROM dbo.ApplicationMigrations WHERE MigrationKey=N'CompoundProfitCommissionWalletV1')
    INSERT dbo.ApplicationMigrations(MigrationKey) VALUES(N'CompoundProfitCommissionWalletV1');
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetByEmail @Email nvarchar(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,ISNULL(w.CommissionBalance,0) CommissionBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,ISNULL(w.HeldCommissionBalance,0) HeldCommissionBalance,
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
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,ISNULL(w.CommissionBalance,0) CommissionBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,ISNULL(w.HeldCommissionBalance,0) HeldCommissionBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Users_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.InvestmentBalance,0) InvestmentBalance,
           ISNULL(w.ProfitBalance,0) ProfitBalance,ISNULL(w.CommissionBalance,0) CommissionBalance,u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    ORDER BY u.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalances_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.CommissionBalance,
           w.HeldInvestmentBalance,w.HeldProfitBalance,w.HeldCommissionBalance,
           w.AvailableBalance,w.HeldBalance
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
           w.InvestmentBalance,w.ProfitBalance,w.CommissionBalance,
           w.HeldInvestmentBalance,w.HeldProfitBalance,w.HeldCommissionBalance,
           w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserProfit_Add
    @UserId bigint,
    @Percentage decimal(9,4),
    @Note nvarchar(500)=NULL,
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Percentage<=0 OR @Percentage>100
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Profit percentage must be greater than 0 and not more than 100.' Message,CAST(NULL AS bigint) Id; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Investment decimal(19,4),@ExistingProfit decimal(19,4),@Commission decimal(19,4),@CompoundBase decimal(19,4),
                @ProfitAmount decimal(19,4),@Available decimal(19,4),@ProfitAfter decimal(19,4),@Seq bigint,@Reference nvarchar(40),
                @AllocationId bigint,@UserStatus int;

        SELECT @Investment=w.InvestmentBalance,@ExistingProfit=w.ProfitBalance,@Commission=w.CommissionBalance,@UserStatus=u.Status
        FROM dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.Users u ON u.Id=w.UserId
        WHERE w.UserId=@UserId;

        IF @Investment IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'User wallet was not found.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF @UserStatus<>1 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Profit can only be added to an active user account.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @CompoundBase=@Investment+@ExistingProfit;
        IF @CompoundBase<=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This user has no investment plus profit balance for compounding.' Message,CAST(NULL AS bigint) Id; RETURN; END
        SET @ProfitAmount=ROUND(@CompoundBase*@Percentage/100.0,4);
        IF @ProfitAmount<=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'The calculated profit is too small to credit.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @Seq=NEXT VALUE FOR dbo.ProfitReferenceSeq;
        SET @Reference=N'PFT-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);

        INSERT dbo.ProfitAllocations(ReferenceNo,UserId,InvestmentBase,ProfitPercentage,ProfitAmount,AdminNote,AddedBy)
        VALUES(@Reference,@UserId,@CompoundBase,@Percentage,@ProfitAmount,@Note,@AdminId);
        SET @AllocationId=SCOPE_IDENTITY();

        UPDATE dbo.UserWallets
        SET ProfitBalance=ProfitBalance+@ProfitAmount,AvailableBalance=AvailableBalance+@ProfitAmount,UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId;

        SELECT @Available=AvailableBalance,@Investment=InvestmentBalance,@ProfitAfter=ProfitBalance,@Commission=CommissionBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'ProfitCredit',@Reference,N'Compound profit credited at '+CONVERT(nvarchar(30),@Percentage)+N'% on investment + profit',@ProfitAmount,0,@Available,@Investment,@ProfitAfter,@Commission,N'ProfitAllocation',@AllocationId,1);

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'User.Profit.Add',N'ProfitAllocation',CONVERT(nvarchar(60),@AllocationId),
               N'UserId='+CONVERT(nvarchar(30),@UserId)+N'; CompoundBase='+CONVERT(nvarchar(50),@CompoundBase)+N'; Percentage='+CONVERT(nvarchar(30),@Percentage)+N'; Profit='+CONVERT(nvarchar(50),@ProfitAmount));

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Compound profit of $'+CONVERT(nvarchar(50),CAST(@ProfitAmount AS decimal(19,2)))+N' credited on base $'+CONVERT(nvarchar(50),CAST(@CompoundBase AS decimal(19,2)))+N'.' Message,
               @AllocationId Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserProfit_AddAll
    @Percentage decimal(9,4),
    @Note nvarchar(500)=NULL,
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Percentage<=0 OR @Percentage>100
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Profit percentage must be greater than 0 and not more than 100.' Message,CAST(NULL AS bigint) Id; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        CREATE TABLE #Eligible(UserId bigint NOT NULL PRIMARY KEY,CompoundBase decimal(19,4) NOT NULL,ProfitAmount decimal(19,4) NOT NULL);
        INSERT #Eligible(UserId,CompoundBase,ProfitAmount)
        SELECT u.Id,w.InvestmentBalance+w.ProfitBalance,ROUND((w.InvestmentBalance+w.ProfitBalance)*@Percentage/100.0,4)
        FROM dbo.Users u
        JOIN dbo.Roles r ON r.Id=u.RoleId
        JOIN dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id
        WHERE r.Name=N'User' AND u.Status=1 AND (w.InvestmentBalance+w.ProfitBalance)>0
          AND ROUND((w.InvestmentBalance+w.ProfitBalance)*@Percentage/100.0,4)>0;

        DECLARE @EligibleCount int=(SELECT COUNT(*) FROM #Eligible),
                @TotalBase decimal(38,4)=(SELECT COALESCE(SUM(CONVERT(decimal(38,4),CompoundBase)),0) FROM #Eligible),
                @TotalProfit decimal(38,4)=(SELECT COALESCE(SUM(CONVERT(decimal(38,4),ProfitAmount)),0) FROM #Eligible);
        IF @EligibleCount=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'No active users currently have an investment plus profit balance for compounding.' Message,CAST(NULL AS bigint) Id; RETURN; END

        DECLARE @BatchSeq bigint=NEXT VALUE FOR dbo.ProfitBatchReferenceSeq,@BatchReference nvarchar(40),@BatchId bigint;
        SET @BatchReference=N'PFB-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@BatchSeq),6);
        INSERT dbo.ProfitBatches(BatchReference,ProfitPercentage,EligibleUserCount,TotalInvestmentBase,TotalProfitAmount,AdminNote,AddedBy)
        VALUES(@BatchReference,@Percentage,@EligibleCount,@TotalBase,@TotalProfit,@Note,@AdminId);
        SET @BatchId=SCOPE_IDENTITY();

        DECLARE @Allocated TABLE(AllocationId bigint,UserId bigint,ReferenceNo nvarchar(40),CompoundBase decimal(19,4),ProfitAmount decimal(19,4));
        INSERT dbo.ProfitAllocations(ReferenceNo,UserId,InvestmentBase,ProfitPercentage,ProfitAmount,AdminNote,AddedBy,BatchId)
        OUTPUT inserted.Id,inserted.UserId,inserted.ReferenceNo,inserted.InvestmentBase,inserted.ProfitAmount
        INTO @Allocated(AllocationId,UserId,ReferenceNo,CompoundBase,ProfitAmount)
        SELECT N'PFT-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),NEXT VALUE FOR dbo.ProfitReferenceSeq),6),
               e.UserId,e.CompoundBase,@Percentage,e.ProfitAmount,@Note,@AdminId,@BatchId
        FROM #Eligible e;

        UPDATE w SET ProfitBalance=ProfitBalance+e.ProfitAmount,AvailableBalance=AvailableBalance+e.ProfitAmount,UpdatedAtUtc=SYSUTCDATETIME()
        FROM dbo.UserWallets w JOIN #Eligible e ON e.UserId=w.UserId;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        SELECT a.UserId,N'ProfitCredit',a.ReferenceNo,
               N'Bulk compound profit at '+CONVERT(nvarchar(30),@Percentage)+N'% (batch '+@BatchReference+N')',
               a.ProfitAmount,0,w.AvailableBalance,w.InvestmentBalance,w.ProfitBalance,w.CommissionBalance,N'ProfitAllocation',a.AllocationId,1
        FROM @Allocated a JOIN dbo.UserWallets w ON w.UserId=a.UserId;

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'User.Profit.AddAll',N'ProfitBatch',CONVERT(nvarchar(60),@BatchId),
               N'Batch='+@BatchReference+N'; EligibleUsers='+CONVERT(nvarchar(20),@EligibleCount)+N'; CompoundBase='+CONVERT(nvarchar(60),@TotalBase)+N'; Percentage='+CONVERT(nvarchar(30),@Percentage)+N'; TotalProfit='+CONVERT(nvarchar(60),@TotalProfit));

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Bulk compound profit batch '+@BatchReference+N' completed. '+CONVERT(nvarchar(20),@EligibleCount)+N' users received $'+CONVERT(nvarchar(60),CAST(@TotalProfit AS decimal(38,2)))+N' total profit on $'+CONVERT(nvarchar(60),CAST(@TotalBase AS decimal(38,2)))+N' combined investment and profit.' Message,
               @BatchId Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawal_Create
    @UserId bigint,@PaymentMethodId int,@Amount decimal(19,4),@DestinationJson nvarchar(max),@DestinationDisplay nvarchar(300)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF ISJSON(@DestinationJson)<>1 BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal destination is invalid.' Message,CAST(NULL AS bigint) Id; RETURN; END
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Can bit,@UserStatus int,@Verified bit,@UserMin decimal(19,4),@UserMax decimal(19,4),@UserFee decimal(9,4),
                @Available decimal(19,4),@Investment decimal(19,4),@Profit decimal(19,4),@Commission decimal(19,4),
                @GlobalMin decimal(19,4),@GlobalMax decimal(19,4),@GlobalFee decimal(9,4),@MethodMin decimal(19,4),@MethodMax decimal(19,4),
                @MethodFee decimal(9,4),@MethodActive bit,@Supports bit,@EffectiveMin decimal(19,4),@EffectiveMax decimal(19,4),@FeePct decimal(9,4),
                @ProfitUsed decimal(19,4),@CommissionUsed decimal(19,4),@InvestmentUsed decimal(19,4),@Remaining decimal(19,4);

        SELECT @Can=u.CanWithdraw,@UserStatus=u.Status,@Verified=u.IsEmailVerified,@UserMin=u.WithdrawalMinOverride,@UserMax=u.WithdrawalMaxOverride,@UserFee=u.WithdrawalFeePercentOverride,
               @Available=w.AvailableBalance,@Investment=w.InvestmentBalance,@Profit=w.ProfitBalance,@Commission=w.CommissionBalance
        FROM dbo.Users u JOIN dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id WHERE u.Id=@UserId;
        SELECT @GlobalMin=DefaultWithdrawalMin,@GlobalMax=DefaultWithdrawalMax,@GlobalFee=DefaultWithdrawalFeePercent FROM dbo.SystemSettings WHERE Id=1;
        SELECT @MethodMin=MinWithdrawal,@MethodMax=MaxWithdrawal,@MethodFee=WithdrawalFeePercent,@MethodActive=IsActive,@Supports=SupportsWithdrawal FROM dbo.PaymentMethods WHERE Id=@PaymentMethodId;

        IF ISNULL(@UserStatus,-1)<>1 OR ISNULL(@Verified,0)<>1 OR ISNULL(@Can,0)<>1 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawals are disabled for this account.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF ISNULL(@MethodActive,0)<>1 OR ISNULL(@Supports,0)<>1 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'The selected withdrawal method is unavailable.' Message,CAST(NULL AS bigint) Id; RETURN; END
        SET @EffectiveMin=CASE WHEN ISNULL(@UserMin,@GlobalMin)>@MethodMin THEN ISNULL(@UserMin,@GlobalMin) ELSE @MethodMin END;
        SET @EffectiveMax=ISNULL(@UserMax,@GlobalMax); IF @MethodMax IS NOT NULL AND @MethodMax<@EffectiveMax SET @EffectiveMax=@MethodMax;
        SET @FeePct=COALESCE(@UserFee,NULLIF(@MethodFee,0),@GlobalFee);
        IF @Amount<@EffectiveMin OR @Amount>@EffectiveMax BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF @Available<@Amount OR (@Investment+@Profit+@Commission)<@Amount BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Insufficient available balance.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @ProfitUsed=CASE WHEN @Profit>=@Amount THEN @Amount ELSE @Profit END;
        SET @Remaining=@Amount-@ProfitUsed;
        SET @CommissionUsed=CASE WHEN @Commission>=@Remaining THEN @Remaining ELSE @Commission END;
        SET @InvestmentUsed=@Remaining-@CommissionUsed;

        DECLARE @Fee decimal(19,4)=ROUND(@Amount*@FeePct/100.0,4),@Net decimal(19,4)=@Amount-ROUND(@Amount*@FeePct/100.0,4),
                @Seq bigint=NEXT VALUE FOR dbo.WithdrawalReferenceSeq,@Ref nvarchar(40),@Balance decimal(19,4),@InvestmentAfter decimal(19,4),
                @ProfitAfter decimal(19,4),@CommissionAfter decimal(19,4);
        IF @Net<=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount must be greater than the fee.' Message,CAST(NULL AS bigint) Id; RETURN; END
        SET @Ref=N'WDL-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance-@Amount,HeldBalance=HeldBalance+@Amount,
            ProfitBalance=ProfitBalance-@ProfitUsed,CommissionBalance=CommissionBalance-@CommissionUsed,InvestmentBalance=InvestmentBalance-@InvestmentUsed,
            HeldProfitBalance=HeldProfitBalance+@ProfitUsed,HeldCommissionBalance=HeldCommissionBalance+@CommissionUsed,HeldInvestmentBalance=HeldInvestmentBalance+@InvestmentUsed,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId AND AvailableBalance>=@Amount AND ProfitBalance>=@ProfitUsed AND CommissionBalance>=@CommissionUsed AND InvestmentBalance>=@InvestmentUsed;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Wallet balances changed while the request was being processed. Please try again.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SELECT @Balance=AvailableBalance,@InvestmentAfter=InvestmentBalance,@ProfitAfter=ProfitBalance,@CommissionAfter=CommissionBalance FROM dbo.UserWallets WHERE UserId=@UserId;
        INSERT dbo.Withdrawals(ReferenceNo,UserId,PaymentMethodId,Amount,FeePercent,FeeAmount,NetAmount,ProfitAmount,CommissionAmount,InvestmentAmount,DestinationJson,DestinationDisplay,Status)
        VALUES(@Ref,@UserId,@PaymentMethodId,@Amount,@FeePct,@Fee,@Net,@ProfitUsed,@CommissionUsed,@InvestmentUsed,@DestinationJson,@DestinationDisplay,0);
        DECLARE @Id bigint=SCOPE_IDENTITY();
        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'WithdrawalDebit',@Ref,N'Withdrawal reserved: profit first, commission second, investment last',0,@Amount,@Balance,@InvestmentAfter,@ProfitAfter,@CommissionAfter,N'Withdrawal',@Id,0);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal submitted. $'+CONVERT(nvarchar(50),CAST(@ProfitUsed AS decimal(19,2)))+N' reserved from profit, $'+CONVERT(nvarchar(50),CAST(@CommissionUsed AS decimal(19,2)))+N' from commission, and $'+CONVERT(nvarchar(50),CAST(@InvestmentUsed AS decimal(19,2)))+N' from investment.' Message,@Id Id;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Complete @Id bigint,@AdminId bigint,@PaymentReference nvarchar(150),@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@PaymentReference)),N'') IS NULL BEGIN SELECT CAST(0 AS bit) Succeeded,N'Payment reference is required to complete a withdrawal.' Message,@Id Id; RETURN; END
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@FeeAmount decimal(19,4),@ProfitAmount decimal(19,4),@CommissionAmount decimal(19,4),@InvestmentAmount decimal(19,4),@Ref nvarchar(40),@CompanyBalance decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@FeeAmount=FeeAmount,@ProfitAmount=ProfitAmount,@CommissionAmount=CommissionAmount,@InvestmentAmount=InvestmentAmount,@Ref=ReferenceNo
        FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
        IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET HeldBalance=HeldBalance-@Amount,HeldProfitBalance=HeldProfitBalance-@ProfitAmount,HeldCommissionBalance=HeldCommissionBalance-@CommissionAmount,HeldInvestmentBalance=HeldInvestmentBalance-@InvestmentAmount,UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId AND HeldBalance>=@Amount AND HeldProfitBalance>=@ProfitAmount AND HeldCommissionBalance>=@CommissionAmount AND HeldInvestmentBalance>=@InvestmentAmount;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END

        UPDATE dbo.Withdrawals SET Status=3,AdminNote=@AdminNote,AdminPaymentReference=@PaymentReference,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        UPDATE dbo.WalletLedger SET IsVisible=1,Description=N'Completed withdrawal: profit $'+CONVERT(nvarchar(50),CAST(@ProfitAmount AS decimal(19,2)))+N', commission $'+CONVERT(nvarchar(50),CAST(@CommissionAmount AS decimal(19,2)))+N', investment $'+CONVERT(nvarchar(50),CAST(@InvestmentAmount AS decimal(19,2))) WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id;

        UPDATE dbo.CompanyWallets SET Balance=Balance-@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId) VALUES(N'WithdrawalSettlement',@Ref,N'Withdrawal settled to user',0,@Amount,@CompanyBalance,N'Withdrawal',@Id);
        IF @FeeAmount>0
        BEGIN
            UPDATE dbo.CompanyWallets SET Balance=Balance+@FeeAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
            SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
            INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId) VALUES(N'WithdrawalFee',@Ref,N'Withdrawal fee transferred to company wallet',@FeeAmount,0,@CompanyBalance,N'WithdrawalFee',@Id);
        END
        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Withdrawal.Complete',N'Withdrawal',CONVERT(nvarchar(60),@Id),@PaymentReference);
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal completed using profit, commission, then investment. Fee was credited to the company wallet.' Message,@Id Id;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Reject @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@ProfitAmount decimal(19,4),@CommissionAmount decimal(19,4),@InvestmentAmount decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@ProfitAmount=ProfitAmount,@CommissionAmount=CommissionAmount,@InvestmentAmount=InvestmentAmount FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
        IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance+@Amount,HeldBalance=HeldBalance-@Amount,
            ProfitBalance=ProfitBalance+@ProfitAmount,CommissionBalance=CommissionBalance+@CommissionAmount,InvestmentBalance=InvestmentBalance+@InvestmentAmount,
            HeldProfitBalance=HeldProfitBalance-@ProfitAmount,HeldCommissionBalance=HeldCommissionBalance-@CommissionAmount,HeldInvestmentBalance=HeldInvestmentBalance-@InvestmentAmount,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId AND HeldBalance>=@Amount AND HeldProfitBalance>=@ProfitAmount AND HeldCommissionBalance>=@CommissionAmount AND HeldInvestmentBalance>=@InvestmentAmount;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END

        UPDATE dbo.Withdrawals SET Status=4,AdminNote=@AdminNote,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        DELETE dbo.WalletLedger WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id AND IsVisible=0;
        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Withdrawal.Reject',N'Withdrawal',CONVERT(nvarchar(60),@Id),@AdminNote);
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal rejected and the original profit, commission, and investment split was restored.' Message,@Id Id;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.UserId=@UserId ORDER BY w.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    ORDER BY CASE WHEN w.Status IN(0,1) THEN 0 ELSE 1 END,w.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.Id=@Id;
END
GO

/* First approved deposit: investment + welcome profit + referral commission wallet. */
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Approve @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Net decimal(19,4),@Ref nvarchar(40),@Amount decimal(19,4),@UserBalance decimal(19,4),
                @InvestmentBalance decimal(19,4),@ProfitBalance decimal(19,4),@CommissionBalance decimal(19,4),@CompanyBalance decimal(19,4),@IsFirstApprovedDeposit bit=0;
        SELECT @Status=Status,@UserId=UserId,@Net=NetAmount,@Ref=ReferenceNo,@Amount=Amount FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id; RETURN; END
        IF @Status<>0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets SET AvailableBalance=AvailableBalance+@Net,InvestmentBalance=InvestmentBalance+@Net,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'User wallet was not found.' Message,@Id Id; RETURN; END
        SET @IsFirstApprovedDeposit=CASE WHEN EXISTS(SELECT 1 FROM dbo.Deposits WHERE UserId=@UserId AND Status=2) THEN 0 ELSE 1 END;
        SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance,@CommissionBalance=CommissionBalance FROM dbo.UserWallets WHERE UserId=@UserId;
        UPDATE dbo.Deposits SET Status=2,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'DepositCredit',@Ref,N'Approved deposit added to investment wallet',@Net,0,@UserBalance,@InvestmentBalance,@ProfitBalance,@CommissionBalance,N'Deposit',@Id,1);

        UPDATE dbo.CompanyWallets SET Balance=Balance+@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId) VALUES(N'DepositReceipt',@Ref,N'Deposit received from user',@Amount,0,@CompanyBalance,N'Deposit',@Id);

        IF @IsFirstApprovedDeposit=1
        BEGIN
            DECLARE @WelcomePercent decimal(9,4)=0,@ReferralPercent decimal(9,4)=0,@WelcomeAmount decimal(19,4)=0,@ReferralAmount decimal(19,4)=0,
                    @WelcomeReference nvarchar(40)=NULL,@ReferralReference nvarchar(40)=NULL,@WelcomeBonusId bigint=NULL,@ReferralId bigint=NULL,@ReferrerUserId bigint=NULL,
                    @ReferrerBalance decimal(19,4),@ReferrerInvestment decimal(19,4),@ReferrerProfit decimal(19,4),@ReferrerCommission decimal(19,4),@Sequence bigint;
            SELECT @WelcomePercent=WelcomeBonusPercent,@ReferralPercent=ReferralCommissionPercent FROM dbo.SystemSettings WITH(HOLDLOCK) WHERE Id=1;
            SET @WelcomeAmount=ROUND(@Amount*@WelcomePercent/100.0,4);
            IF @WelcomeAmount>0
            BEGIN
                SET @Sequence=NEXT VALUE FOR dbo.WelcomeBonusReferenceSeq;
                SET @WelcomeReference=N'WLB-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Sequence),6);
                INSERT dbo.WelcomeBonuses(ReferenceNo,UserId,DepositId,DepositAmount,BonusPercent,BonusAmount) VALUES(@WelcomeReference,@UserId,@Id,@Amount,@WelcomePercent,@WelcomeAmount);
                SET @WelcomeBonusId=SCOPE_IDENTITY();
                UPDATE dbo.UserWallets SET ProfitBalance=ProfitBalance+@WelcomeAmount,AvailableBalance=AvailableBalance+@WelcomeAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId;
                SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance,@CommissionBalance=CommissionBalance FROM dbo.UserWallets WHERE UserId=@UserId;
                INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
                VALUES(@UserId,N'WelcomeBonus',@WelcomeReference,N'Welcome bonus credited to profit wallet',@WelcomeAmount,0,@UserBalance,@InvestmentBalance,@ProfitBalance,@CommissionBalance,N'WelcomeBonus',@WelcomeBonusId,1);
            END

            SELECT @ReferralId=Id,@ReferrerUserId=ReferrerUserId FROM dbo.Referrals WITH(UPDLOCK,HOLDLOCK) WHERE ReferredUserId=@UserId AND IsQualified=0;
            IF @ReferralId IS NOT NULL
            BEGIN
                SET @ReferralAmount=ROUND(@Amount*@ReferralPercent/100.0,4);
                IF @ReferralAmount>0
                BEGIN
                    SET @Sequence=NEXT VALUE FOR dbo.ReferralCommissionReferenceSeq;
                    SET @ReferralReference=N'RFC-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Sequence),6);
                    UPDATE dbo.UserWallets SET CommissionBalance=CommissionBalance+@ReferralAmount,AvailableBalance=AvailableBalance+@ReferralAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@ReferrerUserId;
                    IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Referrer wallet was not found. No deposit changes were committed.' Message,@Id Id; RETURN; END
                    SELECT @ReferrerBalance=AvailableBalance,@ReferrerInvestment=InvestmentBalance,@ReferrerProfit=ProfitBalance,@ReferrerCommission=CommissionBalance FROM dbo.UserWallets WHERE UserId=@ReferrerUserId;
                    INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
                    VALUES(@ReferrerUserId,N'ReferralCommission',@ReferralReference,N'Referral commission credited to commission wallet',@ReferralAmount,0,@ReferrerBalance,@ReferrerInvestment,@ReferrerProfit,@ReferrerCommission,N'Referral',@ReferralId,1);
                END
                UPDATE dbo.Referrals SET IsQualified=1,FirstDepositId=@Id,FirstDepositAmount=@Amount,WelcomeBonusPercent=@WelcomePercent,WelcomeBonusAmount=@WelcomeAmount,WelcomeBonusReferenceNo=@WelcomeReference,
                       ReferralCommissionPercent=@ReferralPercent,ReferralCommissionAmount=@ReferralAmount,ReferralCommissionReferenceNo=@ReferralReference,QualifiedAtUtc=SYSUTCDATETIME()
                WHERE Id=@ReferralId;
            END
        END

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Deposit.Approve',N'Deposit',CONVERT(nvarchar(60),@Id),COALESCE(@AdminNote,N'')+CASE WHEN @IsFirstApprovedDeposit=1 THEN N'; First deposit rewards evaluated.' ELSE N'' END);
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Deposit approved and added to investment wallet.'+CASE WHEN @IsFirstApprovedDeposit=1 THEN N' Welcome bonus went to profit wallet and referral commission went to commission wallet.' ELSE N'' END Message,@Id Id;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.FullName,u.UserTraceId,w.AvailableBalance,w.HeldBalance,w.InvestmentBalance,w.ProfitBalance,w.CommissionBalance,
           w.HeldInvestmentBalance,w.HeldProfitBalance,w.HeldCommissionBalance,
           ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
           ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
           (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
           (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals,
           (SELECT COUNT(*) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1) SuccessfulReferralCount,
           ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1),0) ReferralCommissionEarned
    FROM dbo.Users u JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Id=@UserId;

    SELECT TOP(10) Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger WHERE UserId=@UserId AND IsVisible=1 ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Ledger_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger WHERE UserId=@UserId AND IsVisible=1 ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

PRINT 'Compound profit and separate commission wallet upgrade completed.';
GO
