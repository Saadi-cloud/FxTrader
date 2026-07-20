using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Interfaces.Repositories;
public interface IDepositRepository
{
    Task<DbOperationResult> CreateAsync(long userId, CreateDepositRequest request, string screenshotPath, CancellationToken ct = default);
    Task<IReadOnlyList<DepositTransaction>> GetByUserAsync(long userId, CancellationToken ct = default);
    Task<IReadOnlyList<DepositTransaction>> GetAllAsync(CancellationToken ct = default);
    Task<DepositTransaction?> GetByIdAsync(long id, CancellationToken ct = default);
    Task<DbOperationResult> ApproveAsync(long id, long adminId, string? note, CancellationToken ct = default);
    Task<DbOperationResult> RejectAsync(long id, long adminId, string? note, CancellationToken ct = default);
}
public interface IWithdrawalRepository
{
    Task<DbOperationResult> CreateAsync(long userId, CreateWithdrawalRequest request, CancellationToken ct = default);
    Task<DbOperationResult> CreateOtpChallengeAsync(long userId, CreateWithdrawalRequest request, string codeHash, DateTime expiresAtUtc, CancellationToken ct = default);
    Task<WithdrawalOtpChallenge?> GetOtpChallengeAsync(long challengeId, long userId, CancellationToken ct = default);
    Task<DbOperationResult> ClaimOtpChallengeAsync(long challengeId, long userId, string codeHash, CancellationToken ct = default);
    Task CancelOtpChallengeAsync(long challengeId, long userId, CancellationToken ct = default);
    Task<IReadOnlyList<WithdrawalTransaction>> GetByUserAsync(long userId, CancellationToken ct = default);
    Task<IReadOnlyList<WithdrawalTransaction>> GetAllAsync(CancellationToken ct = default);
    Task<WithdrawalTransaction?> GetByIdAsync(long id, CancellationToken ct = default);
    Task<DbOperationResult> MarkProcessingAsync(long id, long adminId, string? note, CancellationToken ct = default);
    Task<DbOperationResult> CompleteAsync(long id, long adminId, string? paymentReference, string? note, CancellationToken ct = default);
    Task<DbOperationResult> RejectAsync(long id, long adminId, string? note, CancellationToken ct = default);
}
