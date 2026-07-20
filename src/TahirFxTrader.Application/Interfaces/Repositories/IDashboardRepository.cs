using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Interfaces.Repositories;
public interface IDashboardRepository
{
    Task<DashboardData> GetUserDashboardAsync(long userId, CancellationToken ct = default);
    Task<AdminDashboardData> GetAdminDashboardAsync(CancellationToken ct = default);
    Task<IReadOnlyList<LedgerEntry>> GetStatementAsync(long userId, CancellationToken ct = default);
    Task<SystemSettingsModel> GetSettingsAsync(CancellationToken ct = default);
    Task SaveSettingsAsync(SystemSettingsModel model, long adminId, CancellationToken ct = default);
    Task<CompanyLedgerPageModel> GetCompanyLedgerAsync(CancellationToken ct = default);
    Task<decimal> GetReferralCommissionPercentAsync(CancellationToken ct = default);
    Task<ReferralAdminPageModel> GetReferralAdminAsync(CancellationToken ct = default);
    Task SaveWelcomeBonusPercentAsync(decimal percentage, long adminId, CancellationToken ct = default);
    Task SaveReferralCommissionPercentAsync(decimal percentage, long adminId, CancellationToken ct = default);
}
