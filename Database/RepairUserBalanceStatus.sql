USE TahirFxTraderDb;
GO

/* Fixes IndexOutOfRangeException: Status on Admin > User Balances. */
IF COL_LENGTH(N'dbo.Users', N'UserTraceId') IS NULL
BEGIN
    THROW 50001, 'Run UserTraceIdUpgrade.sql before this repair script.', 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalances_GetAll
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.Id AS UserId,
        u.UserTraceId,
        u.FullName,
        u.Email,
        u.Status,
        ISNULL(w.InvestmentBalance, 0) AS InvestmentBalance,
        ISNULL(w.ProfitBalance, 0) AS ProfitBalance,
        ISNULL(w.HeldInvestmentBalance, 0) AS HeldInvestmentBalance,
        ISNULL(w.HeldProfitBalance, 0) AS HeldProfitBalance,
        ISNULL(w.AvailableBalance, 0) AS AvailableBalance,
        ISNULL(w.HeldBalance, 0) AS HeldBalance
    FROM dbo.Users u
    INNER JOIN dbo.UserWallets w ON w.UserId = u.Id
    INNER JOIN dbo.Roles r ON r.Id = u.RoleId
    WHERE r.Name = N'User'
    ORDER BY u.FullName, u.Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalance_Get
    @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.Id AS UserId,
        u.UserTraceId,
        u.FullName,
        u.Email,
        u.Status,
        ISNULL(w.InvestmentBalance, 0) AS InvestmentBalance,
        ISNULL(w.ProfitBalance, 0) AS ProfitBalance,
        ISNULL(w.HeldInvestmentBalance, 0) AS HeldInvestmentBalance,
        ISNULL(w.HeldProfitBalance, 0) AS HeldProfitBalance,
        ISNULL(w.AvailableBalance, 0) AS AvailableBalance,
        ISNULL(w.HeldBalance, 0) AS HeldBalance
    FROM dbo.Users u
    INNER JOIN dbo.UserWallets w ON w.UserId = u.Id
    WHERE u.Id = @UserId;
END
GO

/* Verify that Status is now present in both result sets. */
EXEC dbo.sp_Admin_UserBalances_GetAll;
GO
