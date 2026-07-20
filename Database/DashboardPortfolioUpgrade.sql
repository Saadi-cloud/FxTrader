USE TahirFxTraderDb;
GO

/* Dashboard portfolio refresh: adds Today's PnL to the dashboard result. */
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
        CAST(w.ProfitBalance - ISNULL(@OpeningProfitBalance, 0) AS decimal(19,4)) TodayPnl
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;

    SELECT TOP(10)
        Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,
        InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

PRINT 'Dashboard portfolio and Today PnL upgrade completed.';
GO
