using TahirFxTrader.Domain.Enums;
namespace TahirFxTrader.Domain.Entities;
public sealed class WithdrawalTransaction
{
    public long Id { get; set; }
    public string ReferenceNo { get; set; } = string.Empty;
    public long UserId { get; set; }
    public string UserTraceId { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public string UserEmail { get; set; } = string.Empty;
    public int PaymentMethodId { get; set; }
    public string PaymentMethodName { get; set; } = string.Empty;
    public string WalletSource { get; set; } = "MixedLegacy";
    public decimal Amount { get; set; }
    public decimal FeePercent { get; set; }
    public decimal FeeAmount { get; set; }
    public decimal NetAmount { get; set; }
    public decimal ProfitAmount { get; set; }
    public decimal CommissionAmount { get; set; }
    public decimal InvestmentAmount { get; set; }
    public string DestinationJson { get; set; } = "{}";
    public string DestinationDisplay { get; set; } = string.Empty;
    public TransactionStatus Status { get; set; }
    public string? AdminNote { get; set; }
    public string? AdminPaymentReference { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
}
