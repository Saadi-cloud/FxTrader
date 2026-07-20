using TahirFxTrader.Domain.Enums;
namespace TahirFxTrader.Domain.Entities;
public sealed class PaymentMethod
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public PaymentMethodType MethodType { get; set; }
    public string? AccountTitle { get; set; }
    public string? AccountNumber { get; set; }
    public string? BankName { get; set; }
    public string? WalletAddress { get; set; }
    public string? Network { get; set; }
    public string? QrImagePath { get; set; }
    public string? Instructions { get; set; }
    public decimal MinDeposit { get; set; }
    public decimal? MaxDeposit { get; set; }
    public decimal MinWithdrawal { get; set; }
    public decimal? MaxWithdrawal { get; set; }
    public decimal DepositFeePercent { get; set; }
    public decimal WithdrawalFeePercent { get; set; }
    public bool SupportsDeposit { get; set; }
    public bool SupportsWithdrawal { get; set; }
    public bool IsActive { get; set; }
    public int DisplayOrder { get; set; }
}
