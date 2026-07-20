using System.ComponentModel.DataAnnotations;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Models;
public sealed class CreateDepositRequest
{
    [Range(1, int.MaxValue)] public int PaymentMethodId { get; set; }
    [Range(typeof(decimal), "0.01", "999999999999")] public decimal Amount { get; set; }
    [Required, StringLength(150)] public string TransactionReference { get; set; } = string.Empty;
    [Required, StringLength(200)] public string SenderAccount { get; set; } = string.Empty;
}
public sealed class CreateWithdrawalRequest
{
    [Required, RegularExpression("^(Investment|ProfitCommission)$", ErrorMessage = "Select a valid withdrawal wallet.")]
    public string WalletSource { get; set; } = "Investment";
    [Range(1, int.MaxValue)] public int PaymentMethodId { get; set; }
    [Range(typeof(decimal), "0.01", "999999999999")] public decimal Amount { get; set; }
    [Required] public string DestinationJson { get; set; } = "{}";
    [Required, StringLength(300)] public string DestinationDisplay { get; set; } = string.Empty;
    [Range(typeof(bool), "true", "true", ErrorMessage = "You must confirm the withdrawal details.")] public bool Confirmed { get; set; }
}

public sealed class VerifyWithdrawalOtpRequest
{
    [Range(1, long.MaxValue)] public long ChallengeId { get; set; }
    [Required, RegularExpression("^[0-9]{6}$", ErrorMessage = "Enter the 6-digit verification code.")]
    public string Code { get; set; } = string.Empty;
}

public sealed class WithdrawalOtpPageModel
{
    public long ChallengeId { get; set; }
    public string MaskedEmail { get; set; } = string.Empty;
    public string WalletSource { get; set; } = string.Empty;
    public string PaymentMethodName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string DestinationDisplay { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public int FailedAttempts { get; set; }
    public VerifyWithdrawalOtpRequest Request { get; set; } = new();
}

public sealed class DashboardData
{
    public string FullName { get; set; } = string.Empty;
    public string UserTraceId { get; set; } = string.Empty;
    public decimal AvailableBalance { get; set; }
    public decimal HeldBalance { get; set; }
    public decimal InvestmentBalance { get; set; }
    public decimal ProfitBalance { get; set; }
    public decimal CommissionBalance { get; set; }
    public decimal HeldInvestmentBalance { get; set; }
    public decimal HeldProfitBalance { get; set; }
    public decimal HeldCommissionBalance { get; set; }
    public decimal CompoundProfitBase => InvestmentBalance + ProfitBalance;
    public decimal TodayPnl { get; set; }
    public decimal InvestmentWithdrawalFeePercent { get; set; }
    public decimal TotalDeposits { get; set; }
    public decimal TotalWithdrawals { get; set; }
    public int PendingDeposits { get; set; }
    public int PendingWithdrawals { get; set; }
    public int SuccessfulReferralCount { get; set; }
    public decimal ReferralCommissionEarned { get; set; }
    public decimal ReferralCommissionPercent { get; set; } = 5;
    public string ReferralLink { get; set; } = string.Empty;
    public string ReferralRegisterUrl { get; set; } = string.Empty;
    public IReadOnlyList<LedgerEntry> RecentEntries { get; set; } = Array.Empty<LedgerEntry>();
}
public sealed class SystemSettingsModel
{
    [Range(typeof(decimal), "0", "999999999")] public decimal DefaultWithdrawalMin { get; set; }
    [Range(typeof(decimal), "0", "999999999")] public decimal DefaultWithdrawalMax { get; set; }
    [Range(typeof(decimal), "0", "99.99")] public decimal DefaultWithdrawalFeePercent { get; set; }
    public string SupportEmail { get; set; } = string.Empty;
    public string TelegramUrl { get; set; } = string.Empty;
}
