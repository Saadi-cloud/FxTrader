using TahirFxTrader.Application.Common;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Interfaces.Repositories;
public interface IPaymentMethodRepository
{
    Task<IReadOnlyList<PaymentMethod>> GetActiveDepositMethodsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<PaymentMethod>> GetActiveWithdrawalMethodsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<PaymentMethod>> GetAllAsync(CancellationToken ct = default);
    Task<PaymentMethod?> GetByIdAsync(int id, CancellationToken ct = default);
    Task<DbOperationResult> CreateAsync(PaymentMethod method, long adminId, CancellationToken ct = default);
    Task<DbOperationResult> UpdateAsync(PaymentMethod method, long adminId, CancellationToken ct = default);
    Task<DbOperationResult> DeleteAsync(int id, long adminId, CancellationToken ct = default);
}
