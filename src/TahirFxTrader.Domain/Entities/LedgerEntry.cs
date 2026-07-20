namespace TahirFxTrader.Domain.Entities;
public sealed class LedgerEntry
{
    public long Id { get; set; }
    public long UserId { get; set; }
    public string EntryType { get; set; } = string.Empty;
    public string ReferenceNo { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public decimal Credit { get; set; }
    public decimal Debit { get; set; }
    public decimal BalanceAfter { get; set; }
    public decimal InvestmentBalanceAfter { get; set; }
    public decimal ProfitBalanceAfter { get; set; }
    public decimal CommissionBalanceAfter { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
