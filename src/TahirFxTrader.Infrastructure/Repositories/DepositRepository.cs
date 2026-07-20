using Microsoft.Data.SqlClient;
using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
using TahirFxTrader.Domain.Enums;
using TahirFxTrader.Infrastructure.Data;
namespace TahirFxTrader.Infrastructure.Repositories;
public sealed class DepositRepository : RepositoryBase, IDepositRepository
{
    public DepositRepository(ISqlConnectionFactory connections) : base(connections) { }
    public async Task<DbOperationResult> CreateAsync(long userId, CreateDepositRequest request, string screenshotPath, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Deposit_Create");
        Add(cmd, "@UserId", userId); Add(cmd, "@PaymentMethodId", request.PaymentMethodId); Add(cmd, "@Amount", request.Amount);
        Add(cmd, "@TransactionReference", request.TransactionReference); Add(cmd, "@SenderAccount", request.SenderAccount); Add(cmd, "@ScreenshotPath", screenshotPath);
        return await ReadResultAsync(cmd, ct);
    }
    public Task<IReadOnlyList<DepositTransaction>> GetByUserAsync(long userId, CancellationToken ct = default) => GetListAsync("sp_Deposits_GetByUser", userId, ct);
    public Task<IReadOnlyList<DepositTransaction>> GetAllAsync(CancellationToken ct = default) => GetListAsync("sp_Admin_Deposits_GetAll", null, ct);
    private async Task<IReadOnlyList<DepositTransaction>> GetListAsync(string procedure, long? userId, CancellationToken ct)
    {
        var rows = new List<DepositTransaction>();
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, procedure); if (userId.HasValue) Add(cmd, "@UserId", userId.Value);
        await using var r = await cmd.ExecuteReaderAsync(ct); while (await r.ReadAsync(ct)) rows.Add(Map(r));
        return rows;
    }
    public async Task<DepositTransaction?> GetByIdAsync(long id, CancellationToken ct = default)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, "sp_Admin_Deposit_GetById"); Add(cmd, "@Id", id);
        await using var r = await cmd.ExecuteReaderAsync(ct); return await r.ReadAsync(ct) ? Map(r) : null;
    }
    public Task<DbOperationResult> ApproveAsync(long id, long adminId, string? note, CancellationToken ct = default) => ReviewAsync("sp_Admin_Deposit_Approve", id, adminId, note, ct);
    public Task<DbOperationResult> RejectAsync(long id, long adminId, string? note, CancellationToken ct = default) => ReviewAsync("sp_Admin_Deposit_Reject", id, adminId, note, ct);
    private async Task<DbOperationResult> ReviewAsync(string procedure, long id, long adminId, string? note, CancellationToken ct)
    {
        await using var c = Connections.CreateConnection(); await c.OpenAsync(ct);
        await using var cmd = StoredProcedure(c, procedure); Add(cmd, "@Id", id); Add(cmd, "@AdminId", adminId); Add(cmd, "@AdminNote", note);
        return await ReadResultAsync(cmd, ct);
    }
    private static DepositTransaction Map(SqlDataReader r) => new()
    {
        Id = r.Long("Id"), ReferenceNo = r.String("ReferenceNo"), UserId = r.Long("UserId"), UserTraceId = r.String("UserTraceId"), UserName = r.String("UserName"), UserEmail = r.String("UserEmail"),
        PaymentMethodId = r.Int("PaymentMethodId"), PaymentMethodName = r.String("PaymentMethodName"), Amount = r.Decimal("Amount"), FeeAmount = r.Decimal("FeeAmount"),
        NetAmount = r.Decimal("NetAmount"), SenderAccount = r.String("SenderAccount"), TransactionReference = r.String("TransactionReference"),
        ScreenshotPath = r.String("ScreenshotPath"), Status = (TransactionStatus)r.Int("Status"), AdminNote = r.NullableString("AdminNote"),
        CreatedAtUtc = r.DateTime("CreatedAtUtc"), ReviewedAtUtc = r.NullableDateTime("ReviewedAtUtc")
    };
}
