using Microsoft.Data.SqlClient;
using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
using TahirFxTrader.Domain.Enums;
using TahirFxTrader.Infrastructure.Data;
namespace TahirFxTrader.Infrastructure.Repositories;
public sealed class WithdrawalRepository : RepositoryBase, IWithdrawalRepository
{
    public WithdrawalRepository(ISqlConnectionFactory connections) : base(connections) { }
    public async Task<DbOperationResult> CreateAsync(long userId, CreateWithdrawalRequest request, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Withdrawal_Create");
        Add(cmd, "@UserId", userId); Add(cmd, "@PaymentMethodId", request.PaymentMethodId); Add(cmd, "@WalletSource", request.WalletSource); Add(cmd, "@Amount", request.Amount);
        Add(cmd, "@DestinationJson", request.DestinationJson); Add(cmd, "@DestinationDisplay", request.DestinationDisplay);
        return await ReadResultAsync(cmd, ct);
    }

    public async Task<DbOperationResult> CreateOtpChallengeAsync(long userId, CreateWithdrawalRequest request, string codeHash, DateTime expiresAtUtc, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_WithdrawalOtp_Create");
        Add(cmd, "@UserId", userId); Add(cmd, "@PaymentMethodId", request.PaymentMethodId); Add(cmd, "@WalletSource", request.WalletSource); Add(cmd, "@Amount", request.Amount);
        Add(cmd, "@DestinationJson", request.DestinationJson); Add(cmd, "@DestinationDisplay", request.DestinationDisplay);
        Add(cmd, "@CodeHash", codeHash); Add(cmd, "@ExpiresAtUtc", expiresAtUtc);
        return await ReadResultAsync(cmd, ct);
    }

    public async Task<WithdrawalOtpChallenge?> GetOtpChallengeAsync(long challengeId, long userId, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_WithdrawalOtp_Get");
        Add(cmd, "@Id", challengeId); Add(cmd, "@UserId", userId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;
        return new WithdrawalOtpChallenge
        {
            Id = r.Long("Id"), UserId = r.Long("UserId"), WalletSource = r.String("WalletSource"), PaymentMethodId = r.Int("PaymentMethodId"),
            PaymentMethodName = r.String("PaymentMethodName"), Amount = r.Decimal("Amount"), DestinationJson = r.String("DestinationJson"),
            DestinationDisplay = r.String("DestinationDisplay"), ExpiresAtUtc = r.DateTime("ExpiresAtUtc"), FailedAttempts = r.Int("FailedAttempts"),
            IsUsed = r.Bool("IsUsed"), CreatedAtUtc = r.DateTime("CreatedAtUtc")
        };
    }

    public async Task<DbOperationResult> ClaimOtpChallengeAsync(long challengeId, long userId, string codeHash, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_WithdrawalOtp_Claim");
        Add(cmd, "@Id", challengeId); Add(cmd, "@UserId", userId); Add(cmd, "@CodeHash", codeHash);
        return await ReadResultAsync(cmd, ct);
    }

    public async Task CancelOtpChallengeAsync(long challengeId, long userId, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_WithdrawalOtp_Cancel");
        Add(cmd, "@Id", challengeId); Add(cmd, "@UserId", userId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public Task<IReadOnlyList<WithdrawalTransaction>> GetByUserAsync(long userId, CancellationToken ct = default) => GetListAsync("sp_Withdrawals_GetByUser", userId, ct);
    public Task<IReadOnlyList<WithdrawalTransaction>> GetAllAsync(CancellationToken ct = default) => GetListAsync("sp_Admin_Withdrawals_GetAll", null, ct);
    private async Task<IReadOnlyList<WithdrawalTransaction>> GetListAsync(string procedure, long? userId, CancellationToken ct)
    {
        var rows = new List<WithdrawalTransaction>();
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, procedure); if (userId.HasValue) Add(cmd, "@UserId", userId.Value);
        await using var r = await cmd.ExecuteReaderAsync(ct); while (await r.ReadAsync(ct)) rows.Add(Map(r));
        return rows;
    }
    public async Task<WithdrawalTransaction?> GetByIdAsync(long id, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Admin_Withdrawal_GetById"); Add(cmd, "@Id", id);
        await using var r = await cmd.ExecuteReaderAsync(ct); return await r.ReadAsync(ct) ? Map(r) : null;
    }
    public Task<DbOperationResult> MarkProcessingAsync(long id, long adminId, string? note, CancellationToken ct = default) => ReviewAsync("sp_Admin_Withdrawal_Process", id, adminId, null, note, ct);
    public Task<DbOperationResult> CompleteAsync(long id, long adminId, string? paymentReference, string? note, CancellationToken ct = default) => ReviewAsync("sp_Admin_Withdrawal_Complete", id, adminId, paymentReference, note, ct);
    public Task<DbOperationResult> RejectAsync(long id, long adminId, string? note, CancellationToken ct = default) => ReviewAsync("sp_Admin_Withdrawal_Reject", id, adminId, null, note, ct);
    private async Task<DbOperationResult> ReviewAsync(string procedure, long id, long adminId, string? paymentReference, string? note, CancellationToken ct)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, procedure); Add(cmd, "@Id", id); Add(cmd, "@AdminId", adminId);
        if (procedure == "sp_Admin_Withdrawal_Complete") Add(cmd, "@PaymentReference", paymentReference);
        Add(cmd, "@AdminNote", note); return await ReadResultAsync(cmd, ct);
    }
    private static WithdrawalTransaction Map(SqlDataReader r) => new()
    {
        Id = r.Long("Id"), ReferenceNo = r.String("ReferenceNo"), UserId = r.Long("UserId"), UserTraceId = r.String("UserTraceId"), UserName = r.String("UserName"), UserEmail = r.String("UserEmail"),
        PaymentMethodId = r.Int("PaymentMethodId"), PaymentMethodName = r.String("PaymentMethodName"), WalletSource = r.HasColumn("WalletSource") ? r.String("WalletSource") : "MixedLegacy", Amount = r.Decimal("Amount"), FeePercent = r.Decimal("FeePercent"),
        FeeAmount = r.Decimal("FeeAmount"), NetAmount = r.Decimal("NetAmount"), ProfitAmount = r.Decimal("ProfitAmount"), CommissionAmount = r.HasColumn("CommissionAmount") ? r.Decimal("CommissionAmount") : 0, InvestmentAmount = r.Decimal("InvestmentAmount"), DestinationJson = r.String("DestinationJson"), DestinationDisplay = r.String("DestinationDisplay"),
        Status = (TransactionStatus)r.Int("Status"), AdminNote = r.NullableString("AdminNote"), AdminPaymentReference = r.NullableString("AdminPaymentReference"),
        CreatedAtUtc = r.DateTime("CreatedAtUtc"), CompletedAtUtc = r.NullableDateTime("CompletedAtUtc")
    };
}
