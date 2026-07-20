USE TahirFxTraderDb;
GO

/* Separate investment and profit balances */
IF COL_LENGTH('dbo.UserWallets','InvestmentBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD InvestmentBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_Investment DEFAULT(0);
GO
IF COL_LENGTH('dbo.UserWallets','ProfitBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD ProfitBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_Profit DEFAULT(0);
GO
IF COL_LENGTH('dbo.UserWallets','HeldInvestmentBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD HeldInvestmentBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_HeldInvestment DEFAULT(0);
GO
IF COL_LENGTH('dbo.UserWallets','HeldProfitBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD HeldProfitBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_HeldProfit DEFAULT(0);
GO

/* Existing wallet values are treated as investment because old data had no profit split. */
UPDATE dbo.UserWallets
SET InvestmentBalance = AvailableBalance,
    ProfitBalance = 0,
    HeldInvestmentBalance = HeldBalance,
    HeldProfitBalance = 0
WHERE InvestmentBalance = 0
  AND ProfitBalance = 0
  AND HeldInvestmentBalance = 0
  AND HeldProfitBalance = 0
  AND (AvailableBalance <> 0 OR HeldBalance <> 0);
GO

IF COL_LENGTH('dbo.Withdrawals','ProfitAmount') IS NULL
    ALTER TABLE dbo.Withdrawals ADD ProfitAmount decimal(19,4) NOT NULL CONSTRAINT DF_Withdrawals_ProfitAmount DEFAULT(0);
GO
IF COL_LENGTH('dbo.Withdrawals','InvestmentAmount') IS NULL
    ALTER TABLE dbo.Withdrawals ADD InvestmentAmount decimal(19,4) NOT NULL CONSTRAINT DF_Withdrawals_InvestmentAmount DEFAULT(0);
GO

/* Existing pending withdrawals are considered investment withdrawals. */
UPDATE dbo.Withdrawals
SET InvestmentAmount = Amount,
    ProfitAmount = 0
WHERE InvestmentAmount = 0 AND ProfitAmount = 0;
GO

IF COL_LENGTH('dbo.WalletLedger','InvestmentBalanceAfter') IS NULL
    ALTER TABLE dbo.WalletLedger ADD InvestmentBalanceAfter decimal(19,4) NOT NULL CONSTRAINT DF_Ledger_InvestmentAfter DEFAULT(0);
GO
IF COL_LENGTH('dbo.WalletLedger','ProfitBalanceAfter') IS NULL
    ALTER TABLE dbo.WalletLedger ADD ProfitBalanceAfter decimal(19,4) NOT NULL CONSTRAINT DF_Ledger_ProfitAfter DEFAULT(0);
GO

/* Historical rows had no split; preserve their total as investment for display. */
UPDATE dbo.WalletLedger
SET InvestmentBalanceAfter = BalanceAfter,
    ProfitBalanceAfter = 0
WHERE InvestmentBalanceAfter = 0 AND ProfitBalanceAfter = 0 AND BalanceAfter <> 0;
GO

IF OBJECT_ID(N'dbo.ProfitReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.ProfitReferenceSeq AS bigint START WITH 1 INCREMENT BY 1;
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
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ProfitAllocations_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_ProfitAllocations_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_ProfitAllocations_Admin FOREIGN KEY(AddedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_ProfitAllocations_Percentage CHECK(ProfitPercentage > 0 AND ProfitPercentage <= 100),
    CONSTRAINT CK_ProfitAllocations_Amounts CHECK(InvestmentBase > 0 AND ProfitAmount > 0)
);
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetByEmail @Email nvarchar(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
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
    SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
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

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Users_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,u.CreatedAtUtc
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
    SELECT u.Id UserId,u.FullName,u.Email,u.Status,
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
    SELECT u.Id UserId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
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

    IF @Percentage <= 0 OR @Percentage > 100
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'Profit percentage must be greater than 0 and not more than 100.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Investment decimal(19,4),@ProfitAmount decimal(19,4),@Available decimal(19,4),@ProfitBalance decimal(19,4),
                @Seq bigint,@Reference nvarchar(40),@AllocationId bigint,@UserStatus int;

        SELECT @Investment=w.InvestmentBalance,@UserStatus=u.Status
        FROM dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.Users u ON u.Id=w.UserId
        WHERE w.UserId=@UserId;

        IF @Investment IS NULL
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'User wallet was not found.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END
        IF @UserStatus<>1
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'Profit can only be added to an active user account.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END
        IF @Investment<=0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'This user has no available investment balance for profit calculation.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END

        SET @ProfitAmount=ROUND(@Investment*@Percentage/100.0,4);
        IF @ProfitAmount<=0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'The calculated profit is too small to credit.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END

        SET @Seq=NEXT VALUE FOR dbo.ProfitReferenceSeq;
        SET @Reference=N'PFT-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);

        INSERT dbo.ProfitAllocations(ReferenceNo,UserId,InvestmentBase,ProfitPercentage,ProfitAmount,AdminNote,AddedBy)
        VALUES(@Reference,@UserId,@Investment,@Percentage,@ProfitAmount,@Note,@AdminId);
        SET @AllocationId=SCOPE_IDENTITY();

        UPDATE dbo.UserWallets
        SET ProfitBalance=ProfitBalance+@ProfitAmount,
            AvailableBalance=AvailableBalance+@ProfitAmount,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId;

        SELECT @Available=AvailableBalance,@ProfitBalance=ProfitBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'ProfitCredit',@Reference,N'Profit credited at '+CONVERT(nvarchar(30),@Percentage)+N'%',@ProfitAmount,0,@Available,@Investment,@ProfitBalance,N'ProfitAllocation',@AllocationId,1);

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'User.Profit.Add',N'ProfitAllocation',CONVERT(nvarchar(60),@AllocationId),
               N'UserId='+CONVERT(nvarchar(30),@UserId)+N'; InvestmentBase='+CONVERT(nvarchar(50),@Investment)+N'; Percentage='+CONVERT(nvarchar(30),@Percentage)+N'; Profit='+CONVERT(nvarchar(50),@ProfitAmount));

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Profit of $'+CONVERT(nvarchar(50),CAST(@ProfitAmount AS decimal(19,2)))+N' credited on investment base $'+CONVERT(nvarchar(50),CAST(@Investment AS decimal(19,2)))+N'.' Message,
               @AllocationId Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Approve @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Net decimal(19,4),@Ref nvarchar(40),@Amount decimal(19,4),
                @UserBalance decimal(19,4),@InvestmentBalance decimal(19,4),@ProfitBalance decimal(19,4),@CompanyBalance decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Net=NetAmount,@Ref=ReferenceNo,@Amount=Amount
        FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id; RETURN; END
        IF @Status<>0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance+@Net,
            InvestmentBalance=InvestmentBalance+@Net,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId;

        SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        UPDATE dbo.Deposits SET Status=2,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'DepositCredit',@Ref,N'Approved deposit added to investment',@Net,0,@UserBalance,@InvestmentBalance,@ProfitBalance,N'Deposit',@Id,1);

        UPDATE dbo.CompanyWallets SET Balance=Balance+@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
        VALUES(N'DepositReceipt',@Ref,N'Deposit received from user',@Amount,0,@CompanyBalance,N'Deposit',@Id);

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'Deposit.Approve',N'Deposit',CONVERT(nvarchar(60),@Id),@AdminNote);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Deposit approved and added to user investment balance.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawal_Create
    @UserId bigint,
    @PaymentMethodId int,
    @Amount decimal(19,4),
    @DestinationJson nvarchar(max),
    @DestinationDisplay nvarchar(300)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF ISJSON(@DestinationJson)<>1
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'Withdrawal destination is invalid.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Can bit,@UserStatus int,@Verified bit,@UserMin decimal(19,4),@UserMax decimal(19,4),@UserFee decimal(9,4),
                @Available decimal(19,4),@Investment decimal(19,4),@Profit decimal(19,4),
                @GlobalMin decimal(19,4),@GlobalMax decimal(19,4),@GlobalFee decimal(9,4),
                @MethodMin decimal(19,4),@MethodMax decimal(19,4),@MethodFee decimal(9,4),@MethodActive bit,@Supports bit,
                @EffectiveMin decimal(19,4),@EffectiveMax decimal(19,4),@FeePct decimal(9,4),
                @ProfitUsed decimal(19,4),@InvestmentUsed decimal(19,4);

        SELECT @Can=u.CanWithdraw,@UserStatus=u.Status,@Verified=u.IsEmailVerified,@UserMin=u.WithdrawalMinOverride,
               @UserMax=u.WithdrawalMaxOverride,@UserFee=u.WithdrawalFeePercentOverride,
               @Available=w.AvailableBalance,@Investment=w.InvestmentBalance,@Profit=w.ProfitBalance
        FROM dbo.Users u
        JOIN dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id
        WHERE u.Id=@UserId;

        SELECT @GlobalMin=DefaultWithdrawalMin,@GlobalMax=DefaultWithdrawalMax,@GlobalFee=DefaultWithdrawalFeePercent
        FROM dbo.SystemSettings WHERE Id=1;
        SELECT @MethodMin=MinWithdrawal,@MethodMax=MaxWithdrawal,@MethodFee=WithdrawalFeePercent,@MethodActive=IsActive,@Supports=SupportsWithdrawal
        FROM dbo.PaymentMethods WHERE Id=@PaymentMethodId;

        IF ISNULL(@UserStatus,-1)<>1 OR ISNULL(@Verified,0)<>1 OR ISNULL(@Can,0)<>1
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawals are disabled for this account.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF ISNULL(@MethodActive,0)<>1 OR ISNULL(@Supports,0)<>1
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'The selected withdrawal method is unavailable.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @EffectiveMin=CASE WHEN ISNULL(@UserMin,@GlobalMin)>@MethodMin THEN ISNULL(@UserMin,@GlobalMin) ELSE @MethodMin END;
        SET @EffectiveMax=ISNULL(@UserMax,@GlobalMax);
        IF @MethodMax IS NOT NULL AND @MethodMax<@EffectiveMax SET @EffectiveMax=@MethodMax;
        SET @FeePct=COALESCE(@UserFee,NULLIF(@MethodFee,0),@GlobalFee);

        IF @Amount<@EffectiveMin OR @Amount>@EffectiveMax
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF @Available<@Amount OR (@Investment+@Profit)<@Amount
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Insufficient available balance.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @ProfitUsed=CASE WHEN @Profit>=@Amount THEN @Amount ELSE @Profit END;
        SET @InvestmentUsed=@Amount-@ProfitUsed;

        DECLARE @Fee decimal(19,4)=ROUND(@Amount*@FeePct/100.0,4),
                @Net decimal(19,4)=@Amount-ROUND(@Amount*@FeePct/100.0,4),
                @Seq bigint=NEXT VALUE FOR dbo.WithdrawalReferenceSeq,
                @Ref nvarchar(40),@Balance decimal(19,4),@InvestmentAfter decimal(19,4),@ProfitAfter decimal(19,4);
        IF @Net<=0
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount must be greater than the fee.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @Ref=N'WDL-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance-@Amount,
            HeldBalance=HeldBalance+@Amount,
            ProfitBalance=ProfitBalance-@ProfitUsed,
            InvestmentBalance=InvestmentBalance-@InvestmentUsed,
            HeldProfitBalance=HeldProfitBalance+@ProfitUsed,
            HeldInvestmentBalance=HeldInvestmentBalance+@InvestmentUsed,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId
          AND AvailableBalance>=@Amount
          AND ProfitBalance>=@ProfitUsed
          AND InvestmentBalance>=@InvestmentUsed;

        IF @@ROWCOUNT=0
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Wallet balances changed while the request was being processed. Please try again.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SELECT @Balance=AvailableBalance,@InvestmentAfter=InvestmentBalance,@ProfitAfter=ProfitBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        INSERT dbo.Withdrawals(ReferenceNo,UserId,PaymentMethodId,Amount,FeePercent,FeeAmount,NetAmount,ProfitAmount,InvestmentAmount,DestinationJson,DestinationDisplay,Status)
        VALUES(@Ref,@UserId,@PaymentMethodId,@Amount,@FeePct,@Fee,@Net,@ProfitUsed,@InvestmentUsed,@DestinationJson,@DestinationDisplay,0);
        DECLARE @Id bigint=SCOPE_IDENTITY();

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'WithdrawalDebit',@Ref,N'Completed withdrawal (profit used first)',0,@Amount,@Balance,@InvestmentAfter,@ProfitAfter,N'Withdrawal',@Id,0);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Withdrawal submitted. $'+CONVERT(nvarchar(50),CAST(@ProfitUsed AS decimal(19,2)))+N' reserved from profit and $'+CONVERT(nvarchar(50),CAST(@InvestmentUsed AS decimal(19,2)))+N' from investment.' Message,
               @Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Complete
    @Id bigint,
    @AdminId bigint,
    @PaymentReference nvarchar(150),
    @AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@PaymentReference)),N'') IS NULL
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Payment reference is required to complete a withdrawal.' Message,@Id Id; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@FeeAmount decimal(19,4),@NetAmount decimal(19,4),
                @ProfitAmount decimal(19,4),@InvestmentAmount decimal(19,4),@Ref nvarchar(40),@CompanyBalance decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@FeeAmount=FeeAmount,@NetAmount=NetAmount,
               @ProfitAmount=ProfitAmount,@InvestmentAmount=InvestmentAmount,@Ref=ReferenceNo
        FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;

        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
        IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET HeldBalance=HeldBalance-@Amount,
            HeldProfitBalance=HeldProfitBalance-@ProfitAmount,
            HeldInvestmentBalance=HeldInvestmentBalance-@InvestmentAmount,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId
          AND HeldBalance>=@Amount
          AND HeldProfitBalance>=@ProfitAmount
          AND HeldInvestmentBalance>=@InvestmentAmount;

        IF @@ROWCOUNT=0
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END

        UPDATE dbo.Withdrawals
        SET Status=3,AdminNote=@AdminNote,AdminPaymentReference=@PaymentReference,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME()
        WHERE Id=@Id;

        UPDATE dbo.WalletLedger
        SET IsVisible=1,
            Description=N'Completed withdrawal: profit $'+CONVERT(nvarchar(50),CAST(@ProfitAmount AS decimal(19,2)))+N', investment $'+CONVERT(nvarchar(50),CAST(@InvestmentAmount AS decimal(19,2)))
        WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id;

        UPDATE dbo.CompanyWallets SET Balance=Balance-@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
        VALUES(N'WithdrawalSettlement',@Ref,N'Withdrawal settled to user (gross amount reserved)',0,@Amount,@CompanyBalance,N'Withdrawal',@Id);

        IF @FeeAmount>0
        BEGIN
            UPDATE dbo.CompanyWallets SET Balance=Balance+@FeeAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
            SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
            INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
            VALUES(N'WithdrawalFee',@Ref,N'Withdrawal fee transferred to company wallet',@FeeAmount,0,@CompanyBalance,N'WithdrawalFee',@Id);
        END

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'Withdrawal.Complete',N'Withdrawal',CONVERT(nvarchar(60),@Id),@PaymentReference);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal completed. Profit was consumed before investment and the fee was credited to the company wallet.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Reject @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@ProfitAmount decimal(19,4),@InvestmentAmount decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@ProfitAmount=ProfitAmount,@InvestmentAmount=InvestmentAmount
        FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;

        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
        IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance+@Amount,
            HeldBalance=HeldBalance-@Amount,
            ProfitBalance=ProfitBalance+@ProfitAmount,
            InvestmentBalance=InvestmentBalance+@InvestmentAmount,
            HeldProfitBalance=HeldProfitBalance-@ProfitAmount,
            HeldInvestmentBalance=HeldInvestmentBalance-@InvestmentAmount,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId
          AND HeldBalance>=@Amount
          AND HeldProfitBalance>=@ProfitAmount
          AND HeldInvestmentBalance>=@InvestmentAmount;

        IF @@ROWCOUNT=0
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END

        UPDATE dbo.Withdrawals SET Status=4,AdminNote=@AdminNote,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        DELETE dbo.WalletLedger WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id AND IsVisible=0;
        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'Withdrawal.Reject',N'Withdrawal',CONVERT(nvarchar(60),@Id),@AdminNote);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal rejected and the original profit/investment split was restored.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.FullName,w.AvailableBalance,w.HeldBalance,w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,
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

CREATE OR ALTER PROCEDURE dbo.sp_Ledger_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

PRINT 'Investment/profit wallet upgrade completed.';
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.UserId=@UserId
    ORDER BY w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
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
    SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.Id=@Id;
END
GO
