using Microsoft.Data.SqlClient;
using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Domain.Entities;
using TahirFxTrader.Domain.Enums;
using TahirFxTrader.Infrastructure.Data;
namespace TahirFxTrader.Infrastructure.Repositories;
public sealed class PaymentMethodRepository : RepositoryBase, IPaymentMethodRepository
{
    public PaymentMethodRepository(ISqlConnectionFactory connections) : base(connections) { }
    public Task<IReadOnlyList<PaymentMethod>> GetActiveDepositMethodsAsync(CancellationToken ct = default) => GetListAsync("sp_PaymentMethods_GetActiveDeposit", ct);
    public Task<IReadOnlyList<PaymentMethod>> GetActiveWithdrawalMethodsAsync(CancellationToken ct = default) => GetListAsync("sp_PaymentMethods_GetActiveWithdrawal", ct);
    public Task<IReadOnlyList<PaymentMethod>> GetAllAsync(CancellationToken ct = default) => GetListAsync("sp_Admin_PaymentMethods_GetAll", ct);
    private async Task<IReadOnlyList<PaymentMethod>> GetListAsync(string procedure, CancellationToken ct)
    {
        var rows = new List<PaymentMethod>();
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, procedure);
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct)) rows.Add(Map(reader));
        return rows;
    }
    public async Task<PaymentMethod?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_PaymentMethod_GetById"); Add(command, "@Id", id);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? Map(reader) : null;
    }
    public Task<DbOperationResult> CreateAsync(PaymentMethod method, long adminId, CancellationToken ct = default) => SaveAsync("sp_Admin_PaymentMethod_Create", method, adminId, ct);
    public Task<DbOperationResult> UpdateAsync(PaymentMethod method, long adminId, CancellationToken ct = default) => SaveAsync("sp_Admin_PaymentMethod_Update", method, adminId, ct);
    private async Task<DbOperationResult> SaveAsync(string procedure, PaymentMethod method, long adminId, CancellationToken ct)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, procedure);
        if (method.Id > 0) Add(command, "@Id", method.Id);
        Add(command, "@Name", method.Name); Add(command, "@Code", method.Code); Add(command, "@MethodType", (int)method.MethodType);
        Add(command, "@AccountTitle", method.AccountTitle); Add(command, "@AccountNumber", method.AccountNumber); Add(command, "@BankName", method.BankName);
        Add(command, "@WalletAddress", method.WalletAddress); Add(command, "@Network", method.Network); Add(command, "@QrImagePath", method.QrImagePath);
        Add(command, "@Instructions", method.Instructions); Add(command, "@MinDeposit", method.MinDeposit); Add(command, "@MaxDeposit", method.MaxDeposit);
        Add(command, "@MinWithdrawal", method.MinWithdrawal); Add(command, "@MaxWithdrawal", method.MaxWithdrawal);
        Add(command, "@DepositFeePercent", method.DepositFeePercent); Add(command, "@WithdrawalFeePercent", method.WithdrawalFeePercent);
        Add(command, "@SupportsDeposit", method.SupportsDeposit); Add(command, "@SupportsWithdrawal", method.SupportsWithdrawal);
        Add(command, "@IsActive", method.IsActive); Add(command, "@DisplayOrder", method.DisplayOrder); Add(command, "@AdminId", adminId);
        return await ReadResultAsync(command, ct);
    }
    public async Task<DbOperationResult> DeleteAsync(int id, long adminId, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_Admin_PaymentMethod_Delete"); Add(command, "@Id", id); Add(command, "@AdminId", adminId);
        return await ReadResultAsync(command, ct);
    }
    private static PaymentMethod Map(SqlDataReader r) => new()
    {
        Id = r.Int("Id"), Name = r.String("Name"), Code = r.String("Code"), MethodType = (PaymentMethodType)r.Int("MethodType"),
        AccountTitle = r.NullableString("AccountTitle"), AccountNumber = r.NullableString("AccountNumber"), BankName = r.NullableString("BankName"),
        WalletAddress = r.NullableString("WalletAddress"), Network = r.NullableString("Network"), QrImagePath = r.NullableString("QrImagePath"),
        Instructions = r.NullableString("Instructions"), MinDeposit = r.Decimal("MinDeposit"), MaxDeposit = r.NullableDecimal("MaxDeposit"),
        MinWithdrawal = r.Decimal("MinWithdrawal"), MaxWithdrawal = r.NullableDecimal("MaxWithdrawal"), DepositFeePercent = r.Decimal("DepositFeePercent"),
        WithdrawalFeePercent = r.Decimal("WithdrawalFeePercent"), SupportsDeposit = r.Bool("SupportsDeposit"), SupportsWithdrawal = r.Bool("SupportsWithdrawal"),
        IsActive = r.Bool("IsActive"), DisplayOrder = r.Int("DisplayOrder")
    };
}
