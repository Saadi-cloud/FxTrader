using System.Text.Json;
using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Services;
public sealed class AdminService : IAdminService
{
    private readonly IDashboardRepository _dashboard;
    private readonly IUserRepository _users;
    private readonly IPaymentMethodRepository _methods;
    private readonly IDepositRepository _deposits;
    private readonly IWithdrawalRepository _withdrawals;
    private readonly IFileStorageService _files;
    private readonly IEmailService _email;
    public AdminService(IDashboardRepository dashboard, IUserRepository users, IPaymentMethodRepository methods, IDepositRepository deposits, IWithdrawalRepository withdrawals, IFileStorageService files, IEmailService email)
    { _dashboard = dashboard; _users = users; _methods = methods; _deposits = deposits; _withdrawals = withdrawals; _files = files; _email = email; }
    public Task<AdminDashboardData> GetDashboardAsync(CancellationToken ct = default) => _dashboard.GetAdminDashboardAsync(ct);
    public Task<IReadOnlyList<AdminUserListItem>> GetUsersAsync(CancellationToken ct = default) => _users.GetAllAsync(ct);
    public Task<AdminUserEditModel?> GetUserAsync(long id, CancellationToken ct = default) => _users.GetAdminEditAsync(id, ct);
    public async Task<OperationResult> UpdateUserAsync(AdminUserEditModel model, long adminId, CancellationToken ct = default)
    {
        if (model.WithdrawalMinOverride.HasValue && model.WithdrawalMaxOverride.HasValue && model.WithdrawalMinOverride > model.WithdrawalMaxOverride)
            return OperationResult.Failure("Minimum withdrawal cannot exceed maximum withdrawal.");
        var json = JsonSerializer.Serialize(model.Permissions.Distinct(StringComparer.OrdinalIgnoreCase));
        var result = await _users.UpdateByAdminAsync(model, json, adminId, ct);
        return result.Succeeded ? OperationResult.Success(result.Message) : OperationResult.Failure(result.Message);
    }
    public Task<IReadOnlyList<PaymentMethod>> GetPaymentMethodsAsync(CancellationToken ct = default) => _methods.GetAllAsync(ct);
    public Task<PaymentMethod?> GetPaymentMethodAsync(int id, CancellationToken ct = default) => _methods.GetByIdAsync(id, ct);
    public async Task<OperationResult> SavePaymentMethodAsync(PaymentMethod method, long adminId, FileUploadData? qr, CancellationToken ct = default)
    {
        if (method.MinDeposit < 0 || method.MinWithdrawal < 0 || method.DepositFeePercent is < 0 or >= 100 || method.WithdrawalFeePercent is < 0 or >= 100)
            return OperationResult.Failure("Payment method limits or fee values are invalid.");
        if (qr is not null) method.QrImagePath = await _files.SavePaymentMethodQrAsync(qr, ct);
        var result = method.Id == 0 ? await _methods.CreateAsync(method, adminId, ct) : await _methods.UpdateAsync(method, adminId, ct);
        return result.Succeeded ? OperationResult.Success(result.Message) : OperationResult.Failure(result.Message);
    }
    public async Task<OperationResult> DeletePaymentMethodAsync(int id, long adminId, CancellationToken ct = default)
    { var r = await _methods.DeleteAsync(id, adminId, ct); return r.Succeeded ? OperationResult.Success(r.Message) : OperationResult.Failure(r.Message); }
    public Task<IReadOnlyList<DepositTransaction>> GetDepositsAsync(CancellationToken ct = default) => _deposits.GetAllAsync(ct);
    public Task<DepositTransaction?> GetDepositAsync(long id, CancellationToken ct = default) => _deposits.GetByIdAsync(id, ct);
    public async Task<OperationResult> ApproveDepositAsync(long id, long adminId, string? note, CancellationToken ct = default)
    { var r = await _deposits.ApproveAsync(id, adminId, note, ct); await NotifyDepositAsync(id, r, "Approved", ct); return r.Succeeded ? OperationResult.Success(r.Message) : OperationResult.Failure(r.Message); }
    public async Task<OperationResult> RejectDepositAsync(long id, long adminId, string? note, CancellationToken ct = default)
    { var r = await _deposits.RejectAsync(id, adminId, note, ct); await NotifyDepositAsync(id, r, "Rejected", ct); return r.Succeeded ? OperationResult.Success(r.Message) : OperationResult.Failure(r.Message); }
    private async Task NotifyDepositAsync(long id, DbOperationResult result, string status, CancellationToken ct)
    { if (!result.Succeeded) return; try { var d = await _deposits.GetByIdAsync(id, ct); if (d is not null) await _email.SendTransactionStatusAsync(d.UserEmail, d.UserName, d.ReferenceNo, status, ct); } catch { } }
    public Task<IReadOnlyList<WithdrawalTransaction>> GetWithdrawalsAsync(CancellationToken ct = default) => _withdrawals.GetAllAsync(ct);
    public Task<WithdrawalTransaction?> GetWithdrawalAsync(long id, CancellationToken ct = default) => _withdrawals.GetByIdAsync(id, ct);
    public async Task<OperationResult> ProcessWithdrawalAsync(long id, long adminId, string? note, CancellationToken ct = default)
    { var r = await _withdrawals.MarkProcessingAsync(id, adminId, note, ct); return r.Succeeded ? OperationResult.Success(r.Message) : OperationResult.Failure(r.Message); }
    public async Task<OperationResult> CompleteWithdrawalAsync(long id, long adminId, string? paymentReference, string? note, CancellationToken ct = default)
    { var r = await _withdrawals.CompleteAsync(id, adminId, paymentReference, note, ct); await NotifyWithdrawalAsync(id, r, "Completed", ct); return r.Succeeded ? OperationResult.Success(r.Message) : OperationResult.Failure(r.Message); }
    public async Task<OperationResult> RejectWithdrawalAsync(long id, long adminId, string? note, CancellationToken ct = default)
    { var r = await _withdrawals.RejectAsync(id, adminId, note, ct); await NotifyWithdrawalAsync(id, r, "Rejected", ct); return r.Succeeded ? OperationResult.Success(r.Message) : OperationResult.Failure(r.Message); }
    private async Task NotifyWithdrawalAsync(long id, DbOperationResult result, string status, CancellationToken ct)
    { if (!result.Succeeded) return; try { var w = await _withdrawals.GetByIdAsync(id, ct); if (w is not null) await _email.SendTransactionStatusAsync(w.UserEmail, w.UserName, w.ReferenceNo, status, ct); } catch { } }
    public Task<SystemSettingsModel> GetSettingsAsync(CancellationToken ct = default) => _dashboard.GetSettingsAsync(ct);
    public async Task<OperationResult> SaveSettingsAsync(SystemSettingsModel model, long adminId, CancellationToken ct = default)
    { if (model.DefaultWithdrawalMin > model.DefaultWithdrawalMax) return OperationResult.Failure("Minimum withdrawal cannot exceed maximum withdrawal."); await _dashboard.SaveSettingsAsync(model, adminId, ct); return OperationResult.Success("Settings updated."); }
    public Task<CompanyLedgerPageModel> GetCompanyLedgerAsync(CancellationToken ct = default) => _dashboard.GetCompanyLedgerAsync(ct);
    public Task<IReadOnlyList<AdminUserBalanceItem>> GetUserBalancesAsync(CancellationToken ct = default) => _users.GetBalancesAsync(ct);
    public Task<AdminUserBalanceItem?> GetUserBalanceAsync(long userId, CancellationToken ct = default) => _users.GetBalanceAsync(userId, ct);
    public async Task<OperationResult> ApplyProfitAsync(ApplyProfitRequest model, long adminId, CancellationToken ct = default)
    {
        if (model.ProfitPercentage <= 0 || model.ProfitPercentage > 100) return OperationResult.Failure("Profit percentage must be greater than 0 and not more than 100.");
        var result = await _users.ApplyProfitAsync(model.UserId, model.ProfitPercentage, model.Note, adminId, ct);
        return result.Succeeded ? OperationResult.Success(result.Message) : OperationResult.Failure(result.Message);
    }
    public async Task<OperationResult> ApplyProfitToAllAsync(ApplyProfitToAllRequest model, long adminId, CancellationToken ct = default)
    {
        if (model.ProfitPercentage <= 0 || model.ProfitPercentage > 100)
            return OperationResult.Failure("Profit percentage must be greater than 0 and not more than 100.");
        if (!model.Confirmed)
            return OperationResult.Failure("Confirm the bulk profit allocation before continuing.");
        var result = await _users.ApplyProfitToAllAsync(model.ProfitPercentage, model.Note, adminId, ct);
        return result.Succeeded ? OperationResult.Success(result.Message) : OperationResult.Failure(result.Message);
    }
    public Task<ReferralAdminPageModel> GetReferralAdminAsync(CancellationToken ct = default) => _dashboard.GetReferralAdminAsync(ct);
    public async Task<OperationResult> SaveWelcomeBonusPercentAsync(WelcomeBonusSettingsRequest model, long adminId, CancellationToken ct = default)
    {
        if (model.WelcomeBonusPercent < 0 || model.WelcomeBonusPercent > 100)
            return OperationResult.Failure("Welcome bonus percentage must be between 0 and 100.");
        await _dashboard.SaveWelcomeBonusPercentAsync(model.WelcomeBonusPercent, adminId, ct);
        return OperationResult.Success("Welcome bonus percentage updated.");
    }
    public async Task<OperationResult> SaveReferralCommissionPercentAsync(ReferralCommissionSettingsRequest model, long adminId, CancellationToken ct = default)
    {
        if (model.ReferralCommissionPercent < 0 || model.ReferralCommissionPercent > 100)
            return OperationResult.Failure("Referral commission percentage must be between 0 and 100.");
        await _dashboard.SaveReferralCommissionPercentAsync(model.ReferralCommissionPercent, adminId, ct);
        return OperationResult.Success("Referral commission percentage updated.");
    }

}
