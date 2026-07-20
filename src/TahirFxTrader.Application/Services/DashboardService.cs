using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Services;
public sealed class DashboardService : IDashboardService
{
    private readonly IDashboardRepository _repository;
    public DashboardService(IDashboardRepository repository) => _repository = repository;
    public Task<DashboardData> GetAsync(long userId, CancellationToken ct = default) => _repository.GetUserDashboardAsync(userId, ct);
    public Task<IReadOnlyList<LedgerEntry>> GetStatementAsync(long userId, CancellationToken ct = default) => _repository.GetStatementAsync(userId, ct);
    public Task<decimal> GetReferralCommissionPercentAsync(CancellationToken ct = default) => _repository.GetReferralCommissionPercentAsync(ct);
}
