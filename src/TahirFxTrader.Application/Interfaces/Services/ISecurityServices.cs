using TahirFxTrader.Application.Models;
namespace TahirFxTrader.Application.Interfaces.Services;
public interface IPasswordService { string Hash(string password); bool Verify(string password, string encodedHash); }
public interface ICodeService { string GenerateNumericCode(int digits = 6); string HashCode(string code); bool VerifyCode(string code, string hash); }
public interface IEmailService
{
    Task SendVerificationCodeAsync(string email, string fullName, string code, CancellationToken ct = default);
    Task SendPasswordResetCodeAsync(string email, string fullName, string code, CancellationToken ct = default);
    Task SendWithdrawalVerificationCodeAsync(string email, string fullName, string code, decimal amount, string walletSource, CancellationToken ct = default);
    Task SendTransactionStatusAsync(string email, string fullName, string referenceNo, string status, CancellationToken ct = default);
}
public interface IFileStorageService
{
    Task<string> SavePaymentProofAsync(FileUploadData file, CancellationToken ct = default);
    Task<string> SavePaymentMethodQrAsync(FileUploadData file, CancellationToken ct = default);
}
