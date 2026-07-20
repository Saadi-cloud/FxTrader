using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Interfaces.Services;
public interface IAuthService
{
    Task<OperationResult<string>> RegisterAsync(RegisterRequest request, CancellationToken ct = default);
    Task<OperationResult<AuthenticatedUser>> LoginAsync(LoginRequest request, CancellationToken ct = default);
    Task<OperationResult> VerifyEmailAsync(VerifyEmailRequest request, CancellationToken ct = default);
    Task<OperationResult> ResendVerificationAsync(string email, CancellationToken ct = default);
    Task<OperationResult> ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken ct = default);
    Task<OperationResult> ResetPasswordAsync(ResetPasswordRequest request, CancellationToken ct = default);
    Task<OperationResult> ChangePasswordAsync(long userId, ChangePasswordRequest request, CancellationToken ct = default);
}
public interface IDashboardService
{
    Task<DashboardData> GetAsync(long userId, CancellationToken ct = default);
    Task<IReadOnlyList<LedgerEntry>> GetStatementAsync(long userId, CancellationToken ct = default);
    Task<decimal> GetReferralCommissionPercentAsync(CancellationToken ct = default);
}
public interface IDepositService
{
    Task<IReadOnlyList<PaymentMethod>> GetMethodsAsync(CancellationToken ct = default);
    Task<OperationResult<long>> SubmitAsync(long userId, CreateDepositRequest request, FileUploadData proof, CancellationToken ct = default);
    Task<IReadOnlyList<DepositTransaction>> GetHistoryAsync(long userId, CancellationToken ct = default);
}
public interface IWithdrawalService
{
    Task<IReadOnlyList<PaymentMethod>> GetMethodsAsync(CancellationToken ct = default);
    Task<OperationResult<long>> BeginVerificationAsync(long userId, CreateWithdrawalRequest request, CancellationToken ct = default);
    Task<WithdrawalOtpPageModel?> GetVerificationAsync(long userId, long challengeId, CancellationToken ct = default);
    Task<OperationResult<long>> VerifyAndSubmitAsync(long userId, VerifyWithdrawalOtpRequest request, CancellationToken ct = default);
    Task<OperationResult<long>> ResendVerificationAsync(long userId, long challengeId, CancellationToken ct = default);
    Task<IReadOnlyList<WithdrawalTransaction>> GetHistoryAsync(long userId, CancellationToken ct = default);
}
public interface IAdminService
{
    Task<AdminDashboardData> GetDashboardAsync(CancellationToken ct = default);
    Task<IReadOnlyList<AdminUserListItem>> GetUsersAsync(CancellationToken ct = default);
    Task<AdminUserEditModel?> GetUserAsync(long id, CancellationToken ct = default);
    Task<OperationResult> UpdateUserAsync(AdminUserEditModel model, long adminId, CancellationToken ct = default);
    Task<IReadOnlyList<PaymentMethod>> GetPaymentMethodsAsync(CancellationToken ct = default);
    Task<PaymentMethod?> GetPaymentMethodAsync(int id, CancellationToken ct = default);
    Task<OperationResult> SavePaymentMethodAsync(PaymentMethod method, long adminId, FileUploadData? qr, CancellationToken ct = default);
    Task<OperationResult> DeletePaymentMethodAsync(int id, long adminId, CancellationToken ct = default);
    Task<IReadOnlyList<DepositTransaction>> GetDepositsAsync(CancellationToken ct = default);
    Task<DepositTransaction?> GetDepositAsync(long id, CancellationToken ct = default);
    Task<OperationResult> ApproveDepositAsync(long id, long adminId, string? note, CancellationToken ct = default);
    Task<OperationResult> RejectDepositAsync(long id, long adminId, string? note, CancellationToken ct = default);
    Task<IReadOnlyList<WithdrawalTransaction>> GetWithdrawalsAsync(CancellationToken ct = default);
    Task<WithdrawalTransaction?> GetWithdrawalAsync(long id, CancellationToken ct = default);
    Task<OperationResult> ProcessWithdrawalAsync(long id, long adminId, string? note, CancellationToken ct = default);
    Task<OperationResult> CompleteWithdrawalAsync(long id, long adminId, string? paymentReference, string? note, CancellationToken ct = default);
    Task<OperationResult> RejectWithdrawalAsync(long id, long adminId, string? note, CancellationToken ct = default);
    Task<SystemSettingsModel> GetSettingsAsync(CancellationToken ct = default);
    Task<OperationResult> SaveSettingsAsync(SystemSettingsModel model, long adminId, CancellationToken ct = default);
    Task<CompanyLedgerPageModel> GetCompanyLedgerAsync(CancellationToken ct = default);
    Task<IReadOnlyList<AdminUserBalanceItem>> GetUserBalancesAsync(CancellationToken ct = default);
    Task<AdminUserBalanceItem?> GetUserBalanceAsync(long userId, CancellationToken ct = default);
    Task<OperationResult> ApplyProfitAsync(ApplyProfitRequest model, long adminId, CancellationToken ct = default);
    Task<OperationResult> ApplyProfitToAllAsync(ApplyProfitToAllRequest model, long adminId, CancellationToken ct = default);
    Task<ReferralAdminPageModel> GetReferralAdminAsync(CancellationToken ct = default);
    Task<OperationResult> SaveWelcomeBonusPercentAsync(WelcomeBonusSettingsRequest model, long adminId, CancellationToken ct = default);
    Task<OperationResult> SaveReferralCommissionPercentAsync(ReferralCommissionSettingsRequest model, long adminId, CancellationToken ct = default);
}
