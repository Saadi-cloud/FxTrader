using Microsoft.Data.SqlClient;
using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
using TahirFxTrader.Domain.Enums;
using TahirFxTrader.Infrastructure.Data;
namespace TahirFxTrader.Infrastructure.Repositories;
public sealed class UserRepository : RepositoryBase, IUserRepository
{
    public UserRepository(ISqlConnectionFactory connections) : base(connections) { }
    public Task<UserAccount?> GetByEmailAsync(string email, CancellationToken ct = default) => GetOneAsync("sp_User_GetByEmail", "@Email", email, ct);
    public Task<UserAccount?> GetByIdAsync(long id, CancellationToken ct = default) => GetOneAsync("sp_User_GetById", "@UserId", id, ct);
    private async Task<UserAccount?> GetOneAsync(string procedure, string parameter, object value, CancellationToken ct)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, procedure); Add(command, parameter, value);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? MapUser(reader) : null;
    }
    public async Task<DbOperationResult> CreateAsync(string fullName, string country, string phoneNumber, string email, string passwordHash, string? referralCode, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_User_Register");
        Add(command, "@FullName", fullName); Add(command, "@Country", country); Add(command, "@PhoneNumber", phoneNumber); Add(command, "@Email", email); Add(command, "@PasswordHash", passwordHash); Add(command, "@ReferralCode", string.IsNullOrWhiteSpace(referralCode) ? null : referralCode.Trim().ToUpperInvariant());
        return await ReadResultAsync(command, ct);
    }
    public Task SaveEmailCodeAsync(long userId, string codeHash, DateTime expiresAtUtc, CancellationToken ct = default)
        => ExecuteCodeSaveAsync("sp_User_EmailCode_Save", userId, codeHash, expiresAtUtc, ct);
    public Task SaveResetCodeAsync(long userId, string codeHash, DateTime expiresAtUtc, CancellationToken ct = default)
        => ExecuteCodeSaveAsync("sp_User_ResetCode_Save", userId, codeHash, expiresAtUtc, ct);
    private async Task ExecuteCodeSaveAsync(string procedure, long userId, string codeHash, DateTime expiresAtUtc, CancellationToken ct)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, procedure);
        Add(command, "@UserId", userId); Add(command, "@CodeHash", codeHash); Add(command, "@ExpiresAtUtc", expiresAtUtc);
        await command.ExecuteNonQueryAsync(ct);
    }
    public Task<(string Hash, DateTime ExpiresAtUtc, bool Used)?> GetEmailCodeAsync(long userId, CancellationToken ct = default)
        => GetCodeAsync("sp_User_EmailCode_Get", userId, ct);
    public Task<(string Hash, DateTime ExpiresAtUtc, bool Used)?> GetResetCodeAsync(long userId, CancellationToken ct = default)
        => GetCodeAsync("sp_User_ResetCode_Get", userId, ct);
    private async Task<(string Hash, DateTime ExpiresAtUtc, bool Used)?> GetCodeAsync(string procedure, long userId, CancellationToken ct)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, procedure); Add(command, "@UserId", userId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return null;
        return (reader.String("CodeHash"), reader.DateTime("ExpiresAtUtc"), reader.Bool("IsUsed"));
    }
    public async Task MarkEmailVerifiedAsync(long userId, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_User_Email_Verify"); Add(command, "@UserId", userId);
        await command.ExecuteNonQueryAsync(ct);
    }
    public async Task UpdatePasswordAsync(long userId, string passwordHash, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_User_Password_Update"); Add(command, "@UserId", userId); Add(command, "@PasswordHash", passwordHash);
        await command.ExecuteNonQueryAsync(ct);
    }
    public async Task<IReadOnlyCollection<string>> GetEffectivePermissionsAsync(long userId, CancellationToken ct = default)
    {
        var values = new List<string>();
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_User_Permissions_GetEffective"); Add(command, "@UserId", userId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct)) values.Add(reader.String("PermissionKey"));
        return values;
    }
    public async Task<IReadOnlyList<AdminUserListItem>> GetAllAsync(CancellationToken ct = default)
    {
        var rows = new List<AdminUserListItem>();
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_Admin_Users_GetAll");
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            rows.Add(new AdminUserListItem
            {
                Id = reader.Long("Id"), UserTraceId = reader.String("UserTraceId"), FullName = reader.String("FullName"), Email = reader.String("Email"), Country = reader.String("Country"), PhoneNumber = reader.String("PhoneNumber"), RoleName = reader.String("RoleName"),
                Status = (AccountStatus)reader.Int("Status"), IsEmailVerified = reader.Bool("IsEmailVerified"), CanDeposit = reader.Bool("CanDeposit"), CanWithdraw = reader.Bool("CanWithdraw"),
                AvailableBalance = reader.Decimal("AvailableBalance"), InvestmentBalance = reader.Decimal("InvestmentBalance"), ProfitBalance = reader.Decimal("ProfitBalance"), CommissionBalance = reader.HasColumn("CommissionBalance") ? reader.Decimal("CommissionBalance") : 0, CreatedAtUtc = reader.DateTime("CreatedAtUtc")
            });
        }
        return rows;
    }
    public async Task<AdminUserEditModel?> GetAdminEditAsync(long userId, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_Admin_User_Get"); Add(command, "@UserId", userId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return null;
        var model = new AdminUserEditModel
        {
            Id = reader.Long("Id"), UserTraceId = reader.String("UserTraceId"), FullName = reader.String("FullName"), Country = reader.String("Country"), PhoneNumber = reader.String("PhoneNumber"), Email = reader.String("Email"), RoleName = reader.String("RoleName"),
            Status = (AccountStatus)reader.Int("Status"), IsEmailVerified = reader.Bool("IsEmailVerified"), CanDeposit = reader.Bool("CanDeposit"), CanWithdraw = reader.Bool("CanWithdraw"),
            WithdrawalMinOverride = reader.NullableDecimal("WithdrawalMinOverride"), WithdrawalMaxOverride = reader.NullableDecimal("WithdrawalMaxOverride"), WithdrawalFeePercentOverride = reader.NullableDecimal("WithdrawalFeePercentOverride")
        };
        if (await reader.NextResultAsync(ct)) while (await reader.ReadAsync(ct)) if (reader.Bool("IsAllowed")) model.Permissions.Add(reader.String("PermissionKey"));
        return model;
    }
    public async Task<DbOperationResult> UpdateByAdminAsync(AdminUserEditModel model, string permissionsJson, long adminId, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_Admin_User_Update");
        Add(command, "@UserId", model.Id); Add(command, "@FullName", model.FullName); Add(command, "@Country", model.Country); Add(command, "@PhoneNumber", model.PhoneNumber); Add(command, "@Email", model.Email.ToLowerInvariant());
        Add(command, "@RoleName", model.RoleName); Add(command, "@Status", (int)model.Status); Add(command, "@IsEmailVerified", model.IsEmailVerified); Add(command, "@CanDeposit", model.CanDeposit); Add(command, "@CanWithdraw", model.CanWithdraw);
        Add(command, "@WithdrawalMinOverride", model.WithdrawalMinOverride); Add(command, "@WithdrawalMaxOverride", model.WithdrawalMaxOverride); Add(command, "@WithdrawalFeePercentOverride", model.WithdrawalFeePercentOverride);
        Add(command, "@PermissionsJson", permissionsJson); Add(command, "@AdminId", adminId);
        return await ReadResultAsync(command, ct);
    }
    public async Task<IReadOnlyList<AdminUserBalanceItem>> GetBalancesAsync(CancellationToken ct = default)
    {
        var rows = new List<AdminUserBalanceItem>();
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_Admin_UserBalances_GetAll");
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct)) rows.Add(MapBalance(reader));
        return rows;
    }
    public async Task<AdminUserBalanceItem?> GetBalanceAsync(long userId, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_Admin_UserBalance_Get"); Add(command, "@UserId", userId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? MapBalance(reader) : null;
    }
    public async Task<DbOperationResult> ApplyProfitAsync(long userId, decimal percentage, string? note, long adminId, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_Admin_UserProfit_Add");
        Add(command, "@UserId", userId); Add(command, "@Percentage", percentage); Add(command, "@Note", note); Add(command, "@AdminId", adminId);
        return await ReadResultAsync(command, ct);
    }
    public async Task<DbOperationResult> ApplyProfitToAllAsync(decimal percentage, string? note, long adminId, CancellationToken ct = default)
    {
        await using var connection = Connections.CreateConnection(); await connection.OpenAsync(ct);
        await using var command = StoredProcedure(connection, "sp_Admin_UserProfit_AddAll");
        Add(command, "@Percentage", percentage); Add(command, "@Note", note); Add(command, "@AdminId", adminId);
        return await ReadResultAsync(command, ct);
    }
    private static AdminUserBalanceItem MapBalance(SqlDataReader reader) => new()
    {
        UserId = reader.Long("UserId"), UserTraceId = reader.String("UserTraceId"), FullName = reader.String("FullName"), Email = reader.String("Email"), Status = reader.HasColumn("Status") ? (AccountStatus)reader.Int("Status") : AccountStatus.Pending,
        InvestmentBalance = reader.Decimal("InvestmentBalance"), ProfitBalance = reader.Decimal("ProfitBalance"), CommissionBalance = reader.HasColumn("CommissionBalance") ? reader.Decimal("CommissionBalance") : 0,
        HeldInvestmentBalance = reader.Decimal("HeldInvestmentBalance"), HeldProfitBalance = reader.Decimal("HeldProfitBalance"), HeldCommissionBalance = reader.HasColumn("HeldCommissionBalance") ? reader.Decimal("HeldCommissionBalance") : 0,
        AvailableBalance = reader.Decimal("AvailableBalance"), HeldBalance = reader.Decimal("HeldBalance")
    };
    private static UserAccount MapUser(SqlDataReader reader) => new()
    {
        Id = reader.Long("Id"), UserTraceId = reader.String("UserTraceId"), FullName = reader.String("FullName"), Email = reader.String("Email"), Country = reader.String("Country"), PhoneNumber = reader.String("PhoneNumber"), PasswordHash = reader.String("PasswordHash"),
        RoleName = reader.String("RoleName"), Status = (AccountStatus)reader.Int("Status"), IsEmailVerified = reader.Bool("IsEmailVerified"), CanDeposit = reader.Bool("CanDeposit"), CanWithdraw = reader.Bool("CanWithdraw"),
        WithdrawalMinOverride = reader.NullableDecimal("WithdrawalMinOverride"), WithdrawalMaxOverride = reader.NullableDecimal("WithdrawalMaxOverride"), WithdrawalFeePercentOverride = reader.NullableDecimal("WithdrawalFeePercentOverride"),
        AvailableBalance = reader.Decimal("AvailableBalance"), HeldBalance = reader.Decimal("HeldBalance"), InvestmentBalance = reader.Decimal("InvestmentBalance"), ProfitBalance = reader.Decimal("ProfitBalance"), CommissionBalance = reader.HasColumn("CommissionBalance") ? reader.Decimal("CommissionBalance") : 0,
        HeldInvestmentBalance = reader.Decimal("HeldInvestmentBalance"), HeldProfitBalance = reader.Decimal("HeldProfitBalance"), HeldCommissionBalance = reader.HasColumn("HeldCommissionBalance") ? reader.Decimal("HeldCommissionBalance") : 0, CreatedAtUtc = reader.DateTime("CreatedAtUtc")
    };
}
