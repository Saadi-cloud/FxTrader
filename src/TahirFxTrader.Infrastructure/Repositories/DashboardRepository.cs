using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
using TahirFxTrader.Infrastructure.Data;
namespace TahirFxTrader.Infrastructure.Repositories;
public sealed class DashboardRepository : RepositoryBase, IDashboardRepository
{
    public DashboardRepository(ISqlConnectionFactory connections) : base(connections) { }
    public async Task<DashboardData> GetUserDashboardAsync(long userId, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "dbo.sp_Dashboard_Get"); Add(cmd, "@UserId", userId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var data = new DashboardData();
        if (await r.ReadAsync(ct))
        {
            data.FullName = r.String("FullName"); data.UserTraceId = r.String("UserTraceId"); data.AvailableBalance = r.Decimal("AvailableBalance"); data.HeldBalance = r.Decimal("HeldBalance");
            data.InvestmentBalance = r.Decimal("InvestmentBalance"); data.ProfitBalance = r.Decimal("ProfitBalance"); data.CommissionBalance = r.HasColumn("CommissionBalance") ? r.Decimal("CommissionBalance") : 0;
            data.HeldInvestmentBalance = r.Decimal("HeldInvestmentBalance"); data.HeldProfitBalance = r.Decimal("HeldProfitBalance"); data.HeldCommissionBalance = r.HasColumn("HeldCommissionBalance") ? r.Decimal("HeldCommissionBalance") : 0;
            data.TotalDeposits = r.Decimal("TotalDeposits"); data.TotalWithdrawals = r.Decimal("TotalWithdrawals");
            data.PendingDeposits = r.Int("PendingDeposits"); data.PendingWithdrawals = r.Int("PendingWithdrawals");
            data.SuccessfulReferralCount = r.HasColumn("SuccessfulReferralCount") ? r.Int("SuccessfulReferralCount") : 0;
            data.ReferralCommissionEarned = r.HasColumn("ReferralCommissionEarned") ? r.Decimal("ReferralCommissionEarned") : 0;
            data.ReferralCommissionPercent = r.HasColumn("ReferralCommissionPercent") ? r.Decimal("ReferralCommissionPercent") : 5;
            data.TodayPnl = r.HasColumn("TodayPnl") ? r.Decimal("TodayPnl") : 0;
            data.InvestmentWithdrawalFeePercent = r.HasColumn("InvestmentWithdrawalFeePercent") ? r.Decimal("InvestmentWithdrawalFeePercent") : 0;
        }
        var entries = new List<LedgerEntry>();
        if (await r.NextResultAsync(ct)) while (await r.ReadAsync(ct)) entries.Add(MapLedger(r));
        data.RecentEntries = entries;
        return data;
    }
    public async Task<AdminDashboardData> GetAdminDashboardAsync(CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Admin_Dashboard_Get");
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return new();
        return new AdminDashboardData
        {
            TotalUsers = r.Int("TotalUsers"), ActiveUsers = r.Int("ActiveUsers"), PendingDeposits = r.Int("PendingDeposits"), PendingWithdrawals = r.Int("PendingWithdrawals"),
            TotalWalletBalance = r.Decimal("TotalWalletBalance"), ApprovedDepositsToday = r.Decimal("ApprovedDepositsToday"), CompletedWithdrawalsToday = r.Decimal("CompletedWithdrawalsToday")
        };
    }
    public async Task<IReadOnlyList<LedgerEntry>> GetStatementAsync(long userId, CancellationToken ct = default)
    {
        var rows = new List<LedgerEntry>();
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Ledger_GetByUser"); Add(cmd, "@UserId", userId);
        await using var r = await cmd.ExecuteReaderAsync(ct); while (await r.ReadAsync(ct)) rows.Add(MapLedger(r));
        return rows;
    }
    public async Task<SystemSettingsModel> GetSettingsAsync(CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Settings_Get"); await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return new();
        return new SystemSettingsModel
        {
            DefaultWithdrawalMin = r.Decimal("DefaultWithdrawalMin"), DefaultWithdrawalMax = r.Decimal("DefaultWithdrawalMax"),
            DefaultWithdrawalFeePercent = r.Decimal("DefaultWithdrawalFeePercent"), SupportEmail = r.String("SupportEmail"), TelegramUrl = r.String("TelegramUrl")
        };
    }
    public async Task SaveSettingsAsync(SystemSettingsModel model, long adminId, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Admin_Settings_Save");
        Add(cmd, "@DefaultWithdrawalMin", model.DefaultWithdrawalMin); Add(cmd, "@DefaultWithdrawalMax", model.DefaultWithdrawalMax);
        Add(cmd, "@DefaultWithdrawalFeePercent", model.DefaultWithdrawalFeePercent); Add(cmd, "@SupportEmail", model.SupportEmail); Add(cmd, "@TelegramUrl", model.TelegramUrl); Add(cmd, "@AdminId", adminId);
        await cmd.ExecuteNonQueryAsync(ct);
    }
    public async Task<CompanyLedgerPageModel> GetCompanyLedgerAsync(CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_CompanyLedger_Get");
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var model = new CompanyLedgerPageModel();
        if (await r.ReadAsync(ct)) model.CurrentBalance = r.Decimal("CurrentBalance");
        var entries = new List<CompanyLedgerEntry>();
        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                entries.Add(new CompanyLedgerEntry
                {
                    Id = r.Long("Id"), EntryType = r.String("EntryType"), ReferenceNo = r.String("ReferenceNo"), Description = r.String("Description"),
                    Credit = r.Decimal("Credit"), Debit = r.Decimal("Debit"), BalanceAfter = r.Decimal("BalanceAfter"), CreatedAtUtc = r.DateTime("CreatedAtUtc")
                });
            }
        }
        model.Entries = entries;
        return model;
    }

    public async Task<ReferralAdminPageModel> GetReferralAdminAsync(CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Admin_ReferralDashboard_Get");
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var model = new ReferralAdminPageModel();
        if (await r.ReadAsync(ct))
        {
            model.WelcomeBonusPercent = r.Decimal("WelcomeBonusPercent");
            model.ReferralCommissionPercent = r.Decimal("ReferralCommissionPercent");
            model.RegisteredReferralCount = r.Int("RegisteredReferralCount");
            model.QualifiedReferralCount = r.Int("QualifiedReferralCount");
            model.TotalWelcomeBonusPaid = r.Decimal("TotalWelcomeBonusPaid");
            model.TotalReferralCommissionPaid = r.Decimal("TotalReferralCommissionPaid");
        }
        var rows = new List<AdminReferralItem>();
        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                rows.Add(new AdminReferralItem
                {
                    Id = r.Long("Id"), ReferrerTraceId = r.String("ReferrerTraceId"), ReferrerName = r.String("ReferrerName"),
                    ReferredTraceId = r.String("ReferredTraceId"), ReferredName = r.String("ReferredName"), IsQualified = r.Bool("IsQualified"),
                    FirstDepositAmount = r.Decimal("FirstDepositAmount"), WelcomeBonusAmount = r.Decimal("WelcomeBonusAmount"),
                    ReferralCommissionAmount = r.Decimal("ReferralCommissionAmount"), RegisteredAtUtc = r.DateTime("RegisteredAtUtc"),
                    QualifiedAtUtc = r.NullableDateTime("QualifiedAtUtc")
                });
            }
        }
        model.Referrals = rows;
        return model;
    }
    public async Task SaveWelcomeBonusPercentAsync(decimal percentage, long adminId, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Admin_WelcomeBonusSettings_Save");
        Add(cmd, "@Percentage", percentage); Add(cmd, "@AdminId", adminId);
        await cmd.ExecuteNonQueryAsync(ct);
    }
    public async Task SaveReferralCommissionPercentAsync(decimal percentage, long adminId, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Admin_ReferralCommissionSettings_Save");
        Add(cmd, "@Percentage", percentage); Add(cmd, "@AdminId", adminId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public async Task<decimal> GetReferralCommissionPercentAsync(CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "dbo.sp_Referral_PublicSettings_Get");
        var value = await cmd.ExecuteScalarAsync(ct);
        return value is null || value == DBNull.Value ? 5m : Convert.ToDecimal(value);
    }

    private static LedgerEntry MapLedger(Microsoft.Data.SqlClient.SqlDataReader r) => new()
    {
        Id = r.Long("Id"), UserId = r.Long("UserId"), EntryType = r.String("EntryType"), ReferenceNo = r.String("ReferenceNo"), Description = r.String("Description"),
        Credit = r.Decimal("Credit"), Debit = r.Decimal("Debit"), BalanceAfter = r.Decimal("BalanceAfter"),
        InvestmentBalanceAfter = r.Decimal("InvestmentBalanceAfter"), ProfitBalanceAfter = r.Decimal("ProfitBalanceAfter"), CommissionBalanceAfter = r.HasColumn("CommissionBalanceAfter") ? r.Decimal("CommissionBalanceAfter") : 0, CreatedAtUtc = r.DateTime("CreatedAtUtc")
    };
}
