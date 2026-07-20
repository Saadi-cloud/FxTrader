using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Interfaces.Repositories;
public interface IUserRepository
{
    Task<UserAccount?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task<UserAccount?> GetByIdAsync(long id, CancellationToken ct = default);
    Task<DbOperationResult> CreateAsync(string fullName, string country, string phoneNumber, string email, string passwordHash, string? referralCode, CancellationToken ct = default);
    Task SaveEmailCodeAsync(long userId, string codeHash, DateTime expiresAtUtc, CancellationToken ct = default);
    Task<(string Hash, DateTime ExpiresAtUtc, bool Used)?> GetEmailCodeAsync(long userId, CancellationToken ct = default);
    Task MarkEmailVerifiedAsync(long userId, CancellationToken ct = default);
    Task SaveResetCodeAsync(long userId, string codeHash, DateTime expiresAtUtc, CancellationToken ct = default);
    Task<(string Hash, DateTime ExpiresAtUtc, bool Used)?> GetResetCodeAsync(long userId, CancellationToken ct = default);
    Task UpdatePasswordAsync(long userId, string passwordHash, CancellationToken ct = default);
    Task<IReadOnlyCollection<string>> GetEffectivePermissionsAsync(long userId, CancellationToken ct = default);
    Task<IReadOnlyList<AdminUserListItem>> GetAllAsync(CancellationToken ct = default);
    Task<AdminUserEditModel?> GetAdminEditAsync(long userId, CancellationToken ct = default);
    Task<DbOperationResult> UpdateByAdminAsync(AdminUserEditModel model, string permissionsJson, long adminId, CancellationToken ct = default);
    Task<IReadOnlyList<AdminUserBalanceItem>> GetBalancesAsync(CancellationToken ct = default);
    Task<AdminUserBalanceItem?> GetBalanceAsync(long userId, CancellationToken ct = default);
    Task<DbOperationResult> ApplyProfitAsync(long userId, decimal percentage, string? note, long adminId, CancellationToken ct = default);
    Task<DbOperationResult> ApplyProfitToAllAsync(decimal percentage, string? note, long adminId, CancellationToken ct = default);
}
