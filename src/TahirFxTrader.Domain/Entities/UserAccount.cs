using TahirFxTrader.Domain.Enums;
namespace TahirFxTrader.Domain.Entities;
public sealed class UserAccount
{
    public long Id { get; set; }
    public string UserTraceId { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? CountryCode { get; set; }
    public string Country { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string RoleName { get; set; } = "User";
    public AccountStatus Status { get; set; }
    public bool IsEmailVerified { get; set; }
    public bool CanDeposit { get; set; } = true;
    public bool CanWithdraw { get; set; } = true;
    public decimal? WithdrawalMinOverride { get; set; }
    public decimal? WithdrawalMaxOverride { get; set; }
    public decimal? WithdrawalFeePercentOverride { get; set; }
    public decimal AvailableBalance { get; set; }
    public decimal HeldBalance { get; set; }
    public decimal InvestmentBalance { get; set; }
    public decimal ProfitBalance { get; set; }
    public decimal CommissionBalance { get; set; }
    public decimal HeldInvestmentBalance { get; set; }
    public decimal HeldProfitBalance { get; set; }
    public decimal HeldCommissionBalance { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
