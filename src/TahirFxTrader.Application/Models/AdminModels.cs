using System.ComponentModel.DataAnnotations;
using TahirFxTrader.Domain.Enums;
namespace TahirFxTrader.Application.Models;
public sealed class AdminDashboardData
{
    public int TotalUsers { get; set; }
    public int ActiveUsers { get; set; }
    public int PendingDeposits { get; set; }
    public int PendingWithdrawals { get; set; }
    public decimal TotalWalletBalance { get; set; }
    public decimal ApprovedDepositsToday { get; set; }
    public decimal CompletedWithdrawalsToday { get; set; }
}
public sealed class AdminUserListItem
{
    public long Id { get; set; }
    public string UserTraceId { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string RoleName { get; set; } = string.Empty;
    public AccountStatus Status { get; set; }
    public bool IsEmailVerified { get; set; }
    public bool CanDeposit { get; set; }
    public bool CanWithdraw { get; set; }
    public decimal AvailableBalance { get; set; }
    public decimal InvestmentBalance { get; set; }
    public decimal ProfitBalance { get; set; }
    public decimal CommissionBalance { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
public sealed class AdminUserEditModel
{
    public long Id { get; set; }
    public string UserTraceId { get; set; } = string.Empty;
    [Required, StringLength(120)] public string FullName { get; set; } = string.Empty;
    [Required, StringLength(80)] public string Country { get; set; } = string.Empty;
    [Required, Phone, StringLength(30)] public string PhoneNumber { get; set; } = string.Empty;
    [Required, EmailAddress] public string Email { get; set; } = string.Empty;
    [Required] public string RoleName { get; set; } = "User";
    public AccountStatus Status { get; set; }
    public bool IsEmailVerified { get; set; }
    public bool CanDeposit { get; set; }
    public bool CanWithdraw { get; set; }
    [Range(typeof(decimal), "0", "999999999")] public decimal? WithdrawalMinOverride { get; set; }
    [Range(typeof(decimal), "0", "999999999")] public decimal? WithdrawalMaxOverride { get; set; }
    [Range(typeof(decimal), "0", "99.99")] public decimal? WithdrawalFeePercentOverride { get; set; }
    public List<string> Permissions { get; set; } = new();
}
public sealed class ReviewTransactionRequest
{
    public long Id { get; set; }
    [StringLength(500)] public string? AdminNote { get; set; }
    [StringLength(150)] public string? PaymentReference { get; set; }
}
public sealed class CompanyLedgerPageModel
{
    public decimal CurrentBalance { get; set; }
    public IReadOnlyList<TahirFxTrader.Domain.Entities.CompanyLedgerEntry> Entries { get; set; } = Array.Empty<TahirFxTrader.Domain.Entities.CompanyLedgerEntry>();
}

public sealed class AdminUserBalanceItem
{
    public long UserId { get; set; }
    public string UserTraceId { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public AccountStatus Status { get; set; }
    public decimal InvestmentBalance { get; set; }
    public decimal ProfitBalance { get; set; }
    public decimal CommissionBalance { get; set; }
    public decimal HeldInvestmentBalance { get; set; }
    public decimal HeldProfitBalance { get; set; }
    public decimal HeldCommissionBalance { get; set; }
    public decimal AvailableBalance { get; set; }
    public decimal HeldBalance { get; set; }
    public decimal CompoundProfitBase => InvestmentBalance + ProfitBalance;
    public decimal TotalWalletValue => AvailableBalance + HeldBalance;
}
public sealed class ApplyProfitRequest
{
    public string UserTraceId { get; set; } = string.Empty;
    [Required, Range(typeof(long), "1", "9223372036854775807")] public long UserId { get; set; }
    [Required, Range(typeof(decimal), "0.0001", "100")] public decimal ProfitPercentage { get; set; }
    [StringLength(500)] public string? Note { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public decimal InvestmentBalance { get; set; }
    public decimal ProfitBalance { get; set; }
    public decimal CommissionBalance { get; set; }
    public decimal CompoundProfitBase => InvestmentBalance + ProfitBalance;
    public decimal CalculatedProfit => Math.Round(CompoundProfitBase * ProfitPercentage / 100m, 4);
}

public sealed class ApplyProfitToAllRequest
{
    [Required, Range(typeof(decimal), "0.0001", "100")]
    public decimal ProfitPercentage { get; set; }

    [StringLength(500)]
    public string? Note { get; set; }

    [Range(typeof(bool), "true", "true", ErrorMessage = "Confirm that you want to apply this profit percentage to all eligible users.")]
    public bool Confirmed { get; set; }

    public int EligibleUserCount { get; set; }
    public decimal TotalCompoundingBase { get; set; }
    public decimal EstimatedTotalProfit => Math.Round(TotalCompoundingBase * ProfitPercentage / 100m, 4);
}



public sealed class WelcomeBonusSettingsRequest
{
    [Range(typeof(decimal), "0", "100")]
    public decimal WelcomeBonusPercent { get; set; }
}

public sealed class ReferralCommissionSettingsRequest
{
    [Range(typeof(decimal), "0", "100")]
    public decimal ReferralCommissionPercent { get; set; }
}

public sealed class AdminReferralItem
{
    public long Id { get; set; }
    public string ReferrerTraceId { get; set; } = string.Empty;
    public string ReferrerName { get; set; } = string.Empty;
    public string ReferredTraceId { get; set; } = string.Empty;
    public string ReferredName { get; set; } = string.Empty;
    public bool IsQualified { get; set; }
    public decimal FirstDepositAmount { get; set; }
    public decimal WelcomeBonusAmount { get; set; }
    public decimal ReferralCommissionAmount { get; set; }
    public DateTime RegisteredAtUtc { get; set; }
    public DateTime? QualifiedAtUtc { get; set; }
}

public sealed class ReferralAdminPageModel
{
    public decimal WelcomeBonusPercent { get; set; }
    public decimal ReferralCommissionPercent { get; set; }
    public int RegisteredReferralCount { get; set; }
    public int QualifiedReferralCount { get; set; }
    public decimal TotalWelcomeBonusPaid { get; set; }
    public decimal TotalReferralCommissionPaid { get; set; }
    public IReadOnlyList<AdminReferralItem> Referrals { get; set; } = Array.Empty<AdminReferralItem>();
}
