namespace TahirFxTrader.Domain.Entities;

public sealed class WithdrawalOtpChallenge
{
    public long Id { get; set; }
    public long UserId { get; set; }
    public string WalletSource { get; set; } = string.Empty;
    public int PaymentMethodId { get; set; }
    public string PaymentMethodName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string DestinationJson { get; set; } = "{}";
    public string DestinationDisplay { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public int FailedAttempts { get; set; }
    public bool IsUsed { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
