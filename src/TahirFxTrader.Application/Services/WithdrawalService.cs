using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;

namespace TahirFxTrader.Application.Services;

public sealed class WithdrawalService : IWithdrawalService
{
    private readonly IWithdrawalRepository _withdrawals;
    private readonly IPaymentMethodRepository _methods;
    private readonly IUserRepository _users;
    private readonly ICodeService _codes;
    private readonly IEmailService _email;

    public WithdrawalService(
        IWithdrawalRepository withdrawals,
        IPaymentMethodRepository methods,
        IUserRepository users,
        ICodeService codes,
        IEmailService email)
    {
        _withdrawals = withdrawals;
        _methods = methods;
        _users = users;
        _codes = codes;
        _email = email;
    }

    public Task<IReadOnlyList<PaymentMethod>> GetMethodsAsync(CancellationToken ct = default)
        => _methods.GetActiveWithdrawalMethodsAsync(ct);

    public Task<IReadOnlyList<WithdrawalTransaction>> GetHistoryAsync(long userId, CancellationToken ct = default)
        => _withdrawals.GetByUserAsync(userId, ct);

    public async Task<OperationResult<long>> BeginVerificationAsync(long userId, CreateWithdrawalRequest request, CancellationToken ct = default)
    {
        var validation = await ValidateRequestAsync(request, ct);
        if (!validation.Succeeded) return OperationResult<long>.Failure(validation.Message);

        var user = await _users.GetByIdAsync(userId, ct);
        if (user is null) return OperationResult<long>.Failure("User account was not found.");
        if (string.IsNullOrWhiteSpace(user.Email)) return OperationResult<long>.Failure("Your account does not have an email address.");

        var code = _codes.GenerateNumericCode(6);
        var expiresAtUtc = DateTime.UtcNow.AddMinutes(2);
        var saved = await _withdrawals.CreateOtpChallengeAsync(
            userId,
            request,
            _codes.HashCode(code),
            expiresAtUtc,
            ct);

        if (!saved.Succeeded || !saved.Id.HasValue)
            return OperationResult<long>.Failure(saved.Message);

        try
        {
            var walletLabel = request.WalletSource == "Investment" ? "Investment Wallet" : "Profit + Commission Wallet";
            await _email.SendWithdrawalVerificationCodeAsync(user.Email, user.FullName, code, request.Amount.Value, walletLabel, ct);
        }
        catch
        {
            await _withdrawals.CancelOtpChallengeAsync(saved.Id.Value, userId, ct);
            return OperationResult<long>.Failure("The withdrawal verification email could not be sent. Please try again.");
        }

        return OperationResult<long>.Success(saved.Id.Value, "A 6-digit withdrawal code was sent to your email. It expires in 2 minutes.");
    }

    public async Task<WithdrawalOtpPageModel?> GetVerificationAsync(long userId, long challengeId, CancellationToken ct = default)
    {
        var challenge = await _withdrawals.GetOtpChallengeAsync(challengeId, userId, ct);
        if (challenge is null) return null;
        var user = await _users.GetByIdAsync(userId, ct);
        if (user is null) return null;

        return new WithdrawalOtpPageModel
        {
            ChallengeId = challenge.Id,
            MaskedEmail = MaskEmail(user.Email),
            WalletSource = challenge.WalletSource == "Investment" ? "Investment Wallet" : "Profit + Commission Wallet",
            PaymentMethodName = challenge.PaymentMethodName,
            Amount = challenge.Amount,
            DestinationDisplay = challenge.DestinationDisplay,
            ExpiresAtUtc = challenge.ExpiresAtUtc,
            FailedAttempts = challenge.FailedAttempts,
            Request = new VerifyWithdrawalOtpRequest { ChallengeId = challenge.Id }
        };
    }

    public async Task<OperationResult<long>> VerifyAndSubmitAsync(long userId, VerifyWithdrawalOtpRequest request, CancellationToken ct = default)
    {
        var challenge = await _withdrawals.GetOtpChallengeAsync(request.ChallengeId, userId, ct);
        if (challenge is null) return OperationResult<long>.Failure("This withdrawal verification request is invalid or no longer available.");
        if (challenge.IsUsed) return OperationResult<long>.Failure("This withdrawal verification code has already been used.");
        if (challenge.ExpiresAtUtc <= DateTime.UtcNow) return OperationResult<long>.Failure("The withdrawal code has expired. Request a new code.");
        if (challenge.FailedAttempts >= 5) return OperationResult<long>.Failure("Too many incorrect attempts. Request a new withdrawal code.");

        var claim = await _withdrawals.ClaimOtpChallengeAsync(
            request.ChallengeId,
            userId,
            _codes.HashCode(request.Code),
            ct);

        if (!claim.Succeeded) return OperationResult<long>.Failure(claim.Message);

        var createRequest = new CreateWithdrawalRequest
        {
            WalletSource = challenge.WalletSource,
            PaymentMethodId = challenge.PaymentMethodId,
            Amount = challenge.Amount,
            DestinationJson = challenge.DestinationJson,
            DestinationDisplay = challenge.DestinationDisplay,
            Confirmed = true
        };

        var result = await CreateVerifiedWithdrawalAsync(userId, createRequest, ct);
        if (!result.Succeeded)
            return OperationResult<long>.Failure(result.Message + " Please submit a new withdrawal request if needed.");

        return OperationResult<long>.Success(result.Data, "Withdrawal verified and submitted successfully.");
    }

    public async Task<OperationResult<long>> ResendVerificationAsync(long userId, long challengeId, CancellationToken ct = default)
    {
        var challenge = await _withdrawals.GetOtpChallengeAsync(challengeId, userId, ct);
        if (challenge is null) return OperationResult<long>.Failure("Withdrawal verification request not found.");

        var request = new CreateWithdrawalRequest
        {
            WalletSource = challenge.WalletSource,
            PaymentMethodId = challenge.PaymentMethodId,
            Amount = challenge.Amount,
            DestinationJson = challenge.DestinationJson,
            DestinationDisplay = challenge.DestinationDisplay,
            Confirmed = true
        };

        return await BeginVerificationAsync(userId, request, ct);
    }

    private async Task<OperationResult<long>> CreateVerifiedWithdrawalAsync(long userId, CreateWithdrawalRequest request, CancellationToken ct)
    {
        var validation = await ValidateRequestAsync(request, ct);
        if (!validation.Succeeded) return OperationResult<long>.Failure(validation.Message);

        var result = await _withdrawals.CreateAsync(userId, request, ct);
        return result.Succeeded && result.Id.HasValue
            ? OperationResult<long>.Success(result.Id.Value, result.Message)
            : OperationResult<long>.Failure(result.Message);
    }

    private async Task<OperationResult> ValidateRequestAsync(CreateWithdrawalRequest request, CancellationToken ct)
    {
        if (request.WalletSource != "Investment" && request.WalletSource != "ProfitCommission")
            return OperationResult.Failure("Select Investment or Profit + Commission wallet.");
        if (request.Amount <= 0)
            return OperationResult.Failure("Enter a valid withdrawal amount.");
        if (string.IsNullOrWhiteSpace(request.DestinationDisplay) || string.IsNullOrWhiteSpace(request.DestinationJson))
            return OperationResult.Failure("Enter withdrawal destination details.");

        var method = await _methods.GetByIdAsync(request.PaymentMethodId, ct);
        if (method is null || !method.IsActive || !method.SupportsWithdrawal)
            return OperationResult.Failure("The selected withdrawal method is unavailable.");

        return OperationResult.Success();
    }

    private static string MaskEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@')) return "your registered email";
        var parts = email.Split('@', 2);
        var name = parts[0];
        var visible = name.Length <= 2 ? name[..1] : name[..2];
        return visible + new string('*', Math.Max(3, name.Length - visible.Length)) + "@" + parts[1];
    }
}
