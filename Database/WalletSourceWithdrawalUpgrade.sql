/*
  OLX Trade - Wallet Source Withdrawal Upgrade
  Adds source selection: Investment OR Profit + Commission.
  Investment withdrawals use the admin-controlled investment fee.
  Profit + Commission withdrawals have zero fee.
  Safe to rerun on TahirFxTraderDb.
*/
USE TahirFxTraderDb;
GO

IF COL_LENGTH(N'dbo.Withdrawals', N'WalletSource') IS NULL
BEGIN
    ALTER TABLE dbo.Withdrawals
    ADD WalletSource nvarchar(30) NOT NULL
        CONSTRAINT DF_Withdrawals_WalletSource DEFAULT(N'MixedLegacy');
END
GO

/* Classify older records where the original wallet split is unambiguous. */
UPDATE dbo.Withdrawals
SET WalletSource = CASE
    WHEN InvestmentAmount > 0 AND ISNULL(ProfitAmount,0) = 0 AND ISNULL(CommissionAmount,0) = 0 THEN N'Investment'
    WHEN ISNULL(InvestmentAmount,0) = 0 AND (ISNULL(ProfitAmount,0) > 0 OR ISNULL(CommissionAmount,0) > 0) THEN N'ProfitCommission'
    ELSE N'MixedLegacy'
END
WHERE WalletSource IS NULL OR WalletSource = N'MixedLegacy';
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawal_Create
    @UserId bigint,
    @PaymentMethodId int,
    @WalletSource nvarchar(30),
    @Amount decimal(19,4),
    @DestinationJson nvarchar(max),
    @DestinationDisplay nvarchar(300)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @WalletSource = LTRIM(RTRIM(@WalletSource));

    IF @WalletSource NOT IN (N'Investment', N'ProfitCommission')
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,
               N'Select Investment Wallet or Profit + Commission wallet.' Message,
               CAST(NULL AS bigint) Id;
        RETURN;
    END

    IF ISJSON(@DestinationJson) <> 1
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,
               N'Withdrawal destination is invalid.' Message,
               CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        DECLARE
            @Can bit,
            @UserStatus int,
            @Verified bit,
            @UserMin decimal(19,4),
            @UserMax decimal(19,4),
            @UserInvestmentFee decimal(9,4),
            @Available decimal(19,4),
            @Investment decimal(19,4),
            @Profit decimal(19,4),
            @Commission decimal(19,4),
            @GlobalMin decimal(19,4),
            @GlobalMax decimal(19,4),
            @GlobalInvestmentFee decimal(9,4),
            @MethodMin decimal(19,4),
            @MethodMax decimal(19,4),
            @MethodActive bit,
            @Supports bit,
            @EffectiveMin decimal(19,4),
            @EffectiveMax decimal(19,4),
            @FeePct decimal(9,4),
            @SourceAvailable decimal(19,4),
            @ProfitUsed decimal(19,4) = 0,
            @CommissionUsed decimal(19,4) = 0,
            @InvestmentUsed decimal(19,4) = 0,
            @Remaining decimal(19,4) = 0;

        SELECT
            @Can = u.CanWithdraw,
            @UserStatus = u.Status,
            @Verified = u.IsEmailVerified,
            @UserMin = u.WithdrawalMinOverride,
            @UserMax = u.WithdrawalMaxOverride,
            @UserInvestmentFee = u.WithdrawalFeePercentOverride,
            @Available = w.AvailableBalance,
            @Investment = w.InvestmentBalance,
            @Profit = w.ProfitBalance,
            @Commission = w.CommissionBalance
        FROM dbo.Users u
        JOIN dbo.UserWallets w WITH (UPDLOCK, HOLDLOCK) ON w.UserId = u.Id
        WHERE u.Id = @UserId;

        SELECT
            @GlobalMin = DefaultWithdrawalMin,
            @GlobalMax = DefaultWithdrawalMax,
            @GlobalInvestmentFee = DefaultWithdrawalFeePercent
        FROM dbo.SystemSettings
        WHERE Id = 1;

        SELECT
            @MethodMin = MinWithdrawal,
            @MethodMax = MaxWithdrawal,
            @MethodActive = IsActive,
            @Supports = SupportsWithdrawal
        FROM dbo.PaymentMethods
        WHERE Id = @PaymentMethodId;

        IF ISNULL(@UserStatus, -1) <> 1 OR ISNULL(@Verified, 0) <> 1 OR ISNULL(@Can, 0) <> 1
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'Withdrawals are disabled for this account.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        IF ISNULL(@MethodActive, 0) <> 1 OR ISNULL(@Supports, 0) <> 1
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'The selected withdrawal method is unavailable.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        SET @EffectiveMin = CASE
            WHEN ISNULL(@UserMin, @GlobalMin) > ISNULL(@MethodMin, 0)
                THEN ISNULL(@UserMin, @GlobalMin)
            ELSE ISNULL(@MethodMin, 0)
        END;

        SET @EffectiveMax = ISNULL(@UserMax, @GlobalMax);
        IF @MethodMax IS NOT NULL AND @MethodMax < @EffectiveMax
            SET @EffectiveMax = @MethodMax;

        IF @Amount < @EffectiveMin OR @Amount > @EffectiveMax
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        IF @WalletSource = N'Investment'
        BEGIN
            SET @SourceAvailable = ISNULL(@Investment, 0);
            SET @InvestmentUsed = @Amount;
            SET @FeePct = COALESCE(@UserInvestmentFee, @GlobalInvestmentFee, 0);
        END
        ELSE
        BEGIN
            SET @SourceAvailable = ISNULL(@Profit, 0) + ISNULL(@Commission, 0);
            SET @ProfitUsed = CASE WHEN ISNULL(@Profit,0) >= @Amount THEN @Amount ELSE ISNULL(@Profit,0) END;
            SET @Remaining = @Amount - @ProfitUsed;
            SET @CommissionUsed = @Remaining;
            SET @FeePct = 0;
        END

        IF @Amount <= 0 OR @SourceAvailable < @Amount OR ISNULL(@Available,0) < @Amount
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   CASE WHEN @WalletSource = N'Investment'
                        THEN N'Insufficient Investment Wallet balance.'
                        ELSE N'Insufficient combined Profit and Commission balance.' END Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        DECLARE
            @Fee decimal(19,4) = ROUND(@Amount * @FeePct / 100.0, 4),
            @Net decimal(19,4),
            @Seq bigint = NEXT VALUE FOR dbo.WithdrawalReferenceSeq,
            @Ref nvarchar(40),
            @Balance decimal(19,4),
            @InvestmentAfter decimal(19,4),
            @ProfitAfter decimal(19,4),
            @CommissionAfter decimal(19,4);

        SET @Net = @Amount - @Fee;
        IF @Net <= 0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'Withdrawal amount must be greater than the investment withdrawal fee.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        SET @Ref = N'WDL-' + CONVERT(char(8), SYSUTCDATETIME(), 112)
                 + N'-' + RIGHT(N'000000' + CONVERT(nvarchar(20), @Seq), 6);

        UPDATE dbo.UserWallets
        SET
            AvailableBalance = AvailableBalance - @Amount,
            HeldBalance = HeldBalance + @Amount,
            InvestmentBalance = InvestmentBalance - @InvestmentUsed,
            ProfitBalance = ProfitBalance - @ProfitUsed,
            CommissionBalance = CommissionBalance - @CommissionUsed,
            HeldInvestmentBalance = HeldInvestmentBalance + @InvestmentUsed,
            HeldProfitBalance = HeldProfitBalance + @ProfitUsed,
            HeldCommissionBalance = HeldCommissionBalance + @CommissionUsed,
            UpdatedAtUtc = SYSUTCDATETIME()
        WHERE UserId = @UserId
          AND AvailableBalance >= @Amount
          AND InvestmentBalance >= @InvestmentUsed
          AND ProfitBalance >= @ProfitUsed
          AND CommissionBalance >= @CommissionUsed;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'Wallet balances changed while the request was being processed. Please try again.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        SELECT
            @Balance = AvailableBalance,
            @InvestmentAfter = InvestmentBalance,
            @ProfitAfter = ProfitBalance,
            @CommissionAfter = CommissionBalance
        FROM dbo.UserWallets
        WHERE UserId = @UserId;

        INSERT dbo.Withdrawals
        (
            ReferenceNo, UserId, PaymentMethodId, WalletSource,
            Amount, FeePercent, FeeAmount, NetAmount,
            ProfitAmount, CommissionAmount, InvestmentAmount,
            DestinationJson, DestinationDisplay, Status
        )
        VALUES
        (
            @Ref, @UserId, @PaymentMethodId, @WalletSource,
            @Amount, @FeePct, @Fee, @Net,
            @ProfitUsed, @CommissionUsed, @InvestmentUsed,
            @DestinationJson, @DestinationDisplay, 0
        );

        DECLARE @Id bigint = SCOPE_IDENTITY();

        INSERT dbo.WalletLedger
        (
            UserId, EntryType, ReferenceNo, Description,
            Credit, Debit, BalanceAfter,
            InvestmentBalanceAfter, ProfitBalanceAfter, CommissionBalanceAfter,
            RelatedEntityType, RelatedEntityId, IsVisible
        )
        VALUES
        (
            @UserId, N'WithdrawalDebit', @Ref,
            CASE WHEN @WalletSource = N'Investment'
                 THEN N'Investment Wallet withdrawal reserved'
                 ELSE N'Profit + Commission withdrawal reserved (profit first)' END,
            0, @Amount, @Balance,
            @InvestmentAfter, @ProfitAfter, @CommissionAfter,
            N'Withdrawal', @Id, 0
        );

        COMMIT;

        SELECT CAST(1 AS bit) Succeeded,
               CASE WHEN @WalletSource = N'Investment'
                    THEN N'Investment withdrawal submitted. Fee: '
                       + CONVERT(nvarchar(30), CAST(@FeePct AS decimal(9,2))) + N'%. Amount to receive: $'
                       + CONVERT(nvarchar(50), CAST(@Net AS decimal(19,2))) + N'.'
                    ELSE N'Profit + Commission withdrawal submitted with 0% fee. $'
                       + CONVERT(nvarchar(50), CAST(@ProfitUsed AS decimal(19,2))) + N' reserved from Profit and $'
                       + CONVERT(nvarchar(50), CAST(@CommissionUsed AS decimal(19,2))) + N' from Commission.' END Message,
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

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,
        w.PaymentMethodId,p.Name PaymentMethodName,w.WalletSource,
        w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,
        w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,
        w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,
        w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id = w.UserId
    JOIN dbo.PaymentMethods p ON p.Id = w.PaymentMethodId
    WHERE w.UserId = @UserId
    ORDER BY w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,
        w.PaymentMethodId,p.Name PaymentMethodName,w.WalletSource,
        w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,
        w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,
        w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,
        w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id = w.UserId
    JOIN dbo.PaymentMethods p ON p.Id = w.PaymentMethodId
    ORDER BY CASE WHEN w.Status IN (0,1) THEN 0 ELSE 1 END, w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,
        w.PaymentMethodId,p.Name PaymentMethodName,w.WalletSource,
        w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,
        w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,
        w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,
        w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id = w.UserId
    JOIN dbo.PaymentMethods p ON p.Id = w.PaymentMethodId
    WHERE w.Id = @Id;
END
GO

/* Include the effective investment-withdrawal fee in the dashboard result. */
CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayStartUtc datetime2(0) = CONVERT(date, SYSUTCDATETIME());
    DECLARE @OpeningProfitBalance decimal(19,4);

    SELECT TOP(1) @OpeningProfitBalance = ProfitBalanceAfter
    FROM dbo.WalletLedger
    WHERE UserId = @UserId
      AND IsVisible = 1
      AND CreatedAtUtc < @TodayStartUtc
    ORDER BY CreatedAtUtc DESC, Id DESC;

    SELECT
        u.FullName,
        u.UserTraceId,
        w.AvailableBalance,
        w.HeldBalance,
        w.InvestmentBalance,
        w.ProfitBalance,
        w.CommissionBalance,
        w.HeldInvestmentBalance,
        w.HeldProfitBalance,
        w.HeldCommissionBalance,
        ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
        ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
        (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
        (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals,
        (SELECT COUNT(*) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1) SuccessfulReferralCount,
        ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1),0) ReferralCommissionEarned,
        CAST(w.ProfitBalance - ISNULL(@OpeningProfitBalance, 0) AS decimal(19,4)) TodayPnl,
        CAST(COALESCE(u.WithdrawalFeePercentOverride, s.DefaultWithdrawalFeePercent, 0) AS decimal(9,4)) InvestmentWithdrawalFeePercent
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId = u.Id
    JOIN dbo.SystemSettings s ON s.Id = 1
    WHERE u.Id = @UserId;

    SELECT TOP(10)
        Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,
        InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId = @UserId AND IsVisible = 1
    ORDER BY CreatedAtUtc DESC, Id DESC;
END
GO

PRINT 'Wallet source withdrawal upgrade completed.';
GO
