/* OLX Trade — dashboard referral preview + 5% commission setting
   Run against the existing TahirFxTraderDb database.
*/
USE TahirFxTraderDb;
GO

IF COL_LENGTH('dbo.SystemSettings','ReferralCommissionPercent') IS NULL
BEGIN
    ALTER TABLE dbo.SystemSettings
    ADD ReferralCommissionPercent decimal(9,4) NOT NULL
        CONSTRAINT DF_SystemSettings_ReferralCommission_Preview DEFAULT(5);
END
GO

UPDATE dbo.SystemSettings
SET ReferralCommissionPercent = 5,
    UpdatedAtUtc = SYSUTCDATETIME()
WHERE Id = 1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Referral_PublicSettings_Get
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(ISNULL(ReferralCommissionPercent,5) AS decimal(9,4))
    FROM dbo.SystemSettings
    WHERE Id = 1;
END
GO

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
        CAST(ISNULL(s.ReferralCommissionPercent,5) AS decimal(9,4)) ReferralCommissionPercent,
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

PRINT 'Dashboard referral preview upgrade completed. Referral commission set to 5%.';
GO
