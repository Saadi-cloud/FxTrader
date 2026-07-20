using Microsoft.AspNetCore.Http;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Web.Models;
public sealed class DepositPageViewModel
{
    public IReadOnlyList<PaymentMethod> Methods { get; set; } = Array.Empty<PaymentMethod>();
    public CreateDepositRequest Request { get; set; } = new();
    public IFormFile? Screenshot { get; set; }
}
public sealed class WithdrawalPageViewModel
{
    public IReadOnlyList<PaymentMethod> Methods { get; set; } = Array.Empty<PaymentMethod>();
    public CreateWithdrawalRequest Request { get; set; } = new();
    public decimal AvailableBalance { get; set; }
    public decimal InvestmentBalance { get; set; }
    public decimal ProfitBalance { get; set; }
    public decimal CommissionBalance { get; set; }
    public decimal ProfitCommissionBalance => ProfitBalance + CommissionBalance;
    public decimal InvestmentWithdrawalFeePercent { get; set; }
}

public sealed class ReferralLandingViewModel
{
    public string ReferralCode { get; set; } = string.Empty;
    public string RegisterUrl { get; set; } = string.Empty;
    public string ShareUrl { get; set; } = string.Empty;
    public string CanonicalUrl { get; set; } = string.Empty;
    public string ShareImageUrl { get; set; } = string.Empty;
    public decimal CommissionPercent { get; set; } = 5;
}
