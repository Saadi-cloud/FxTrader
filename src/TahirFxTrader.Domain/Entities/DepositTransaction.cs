using TahirFxTrader.Domain.Enums;
namespace TahirFxTrader.Domain.Entities;
public sealed class DepositTransaction
{
    public long Id { get; set; }
    public string ReferenceNo { get; set; } = string.Empty;
    public long UserId { get; set; }
    public string UserTraceId { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public string UserEmail { get; set; } = string.Empty;
    public int PaymentMethodId { get; set; }
    public string PaymentMethodName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public decimal FeeAmount { get; set; }
    public decimal NetAmount { get; set; }
    public string SenderAccount { get; set; } = string.Empty;
    public string TransactionReference { get; set; } = string.Empty;
    public string ScreenshotPath { get; set; } = string.Empty;
    public TransactionStatus Status { get; set; }
    public string? AdminNote { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? ReviewedAtUtc { get; set; }
}
