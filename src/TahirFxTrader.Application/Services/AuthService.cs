using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Enums;
namespace TahirFxTrader.Application.Services;
public sealed class AuthService : IAuthService
{
    private readonly IUserRepository _users;
    private readonly IPasswordService _passwords;
    private readonly ICodeService _codes;
    private readonly IEmailService _email;
    public AuthService(IUserRepository users, IPasswordService passwords, ICodeService codes, IEmailService email)
    { _users = users; _passwords = passwords; _codes = codes; _email = email; }

    public async Task<OperationResult<string>> RegisterAsync(RegisterRequest request, CancellationToken ct = default)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        if (await _users.GetByEmailAsync(email, ct) is not null)
            return OperationResult<string>.Failure("An account already exists with this email address.");
        var created = await _users.CreateAsync(request.FullName.Trim(), request.Country.Trim(), request.PhoneNumber.Trim(), email, _passwords.Hash(request.Password), request.ReferralCode, ct);
        if (!created.Succeeded || created.Id is null) return OperationResult<string>.Failure(created.Message);
        var registeredUser = await _users.GetByIdAsync(created.Id.Value, ct);
        var traceText = registeredUser is null ? string.Empty : $" Your User ID is {registeredUser.UserTraceId}.";
        var code = _codes.GenerateNumericCode();
        await _users.SaveEmailCodeAsync(created.Id.Value, _codes.HashCode(code), DateTime.UtcNow.AddMinutes(15), ct);
        try
        {
            await _email.SendVerificationCodeAsync(email, request.FullName.Trim(), code, ct);
            return OperationResult<string>.Success(email, "Account created." + traceText + " Enter the verification code sent to your email.");
        }
        catch
        {
            return OperationResult<string>.Success(email, "Account created." + traceText + " The verification email could not be delivered. Configure SMTP or use resend verification.");
        }
    }

    public async Task<OperationResult<AuthenticatedUser>> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var user = await _users.GetByEmailAsync(request.Email.Trim().ToLowerInvariant(), ct);
        if (user is null || !_passwords.Verify(request.Password, user.PasswordHash))
            return OperationResult<AuthenticatedUser>.Failure("Invalid email address or password.");
        if (!user.IsEmailVerified)
            return OperationResult<AuthenticatedUser>.Failure("Verify your email address before logging in.");
        if (user.Status != AccountStatus.Active)
            return OperationResult<AuthenticatedUser>.Failure($"Your account is {user.Status.ToString().ToLowerInvariant()}. Contact support.");
        var permissions = await _users.GetEffectivePermissionsAsync(user.Id, ct);
        return OperationResult<AuthenticatedUser>.Success(new AuthenticatedUser(user.Id, user.UserTraceId, user.FullName, user.Email, user.RoleName, permissions));
    }

    public async Task<OperationResult> VerifyEmailAsync(VerifyEmailRequest request, CancellationToken ct = default)
    {
        var user = await _users.GetByEmailAsync(request.Email.Trim().ToLowerInvariant(), ct);
        if (user is null) return OperationResult.Failure("Account not found.");
        if (user.IsEmailVerified) return OperationResult.Success("Email address is already verified.");
        var code = await _users.GetEmailCodeAsync(user.Id, ct);
        if (code is null || code.Value.Used || code.Value.ExpiresAtUtc < DateTime.UtcNow || !_codes.VerifyCode(request.Code, code.Value.Hash))
            return OperationResult.Failure("The verification code is invalid or has expired.");
        await _users.MarkEmailVerifiedAsync(user.Id, ct);
        return OperationResult.Success("Email verified. You can now log in.");
    }

    public async Task<OperationResult> ResendVerificationAsync(string email, CancellationToken ct = default)
    {
        var user = await _users.GetByEmailAsync(email.Trim().ToLowerInvariant(), ct);
        if (user is null) return OperationResult.Failure("Account not found.");
        if (user.IsEmailVerified) return OperationResult.Success("Email address is already verified.");
        var code = _codes.GenerateNumericCode();
        await _users.SaveEmailCodeAsync(user.Id, _codes.HashCode(code), DateTime.UtcNow.AddMinutes(15), ct);
        try { await _email.SendVerificationCodeAsync(user.Email, user.FullName, code, ct); }
        catch { return OperationResult.Failure("The verification email could not be sent. Check the SMTP configuration."); }
        return OperationResult.Success("A new verification code was sent.");
    }

    public async Task<OperationResult> ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken ct = default)
    {
        var user = await _users.GetByEmailAsync(request.Email.Trim().ToLowerInvariant(), ct);
        if (user is not null)
        {
            var code = _codes.GenerateNumericCode();
            await _users.SaveResetCodeAsync(user.Id, _codes.HashCode(code), DateTime.UtcNow.AddMinutes(15), ct);
            try { await _email.SendPasswordResetCodeAsync(user.Email, user.FullName, code, ct); }
            catch { return OperationResult.Failure("The reset email could not be sent. Please contact support."); }
        }
        return OperationResult.Success("If the email exists, a password reset code has been sent.");
    }

    public async Task<OperationResult> ResetPasswordAsync(ResetPasswordRequest request, CancellationToken ct = default)
    {
        var user = await _users.GetByEmailAsync(request.Email.Trim().ToLowerInvariant(), ct);
        if (user is null) return OperationResult.Failure("The reset code is invalid or has expired.");
        var code = await _users.GetResetCodeAsync(user.Id, ct);
        if (code is null || code.Value.Used || code.Value.ExpiresAtUtc < DateTime.UtcNow || !_codes.VerifyCode(request.Code, code.Value.Hash))
            return OperationResult.Failure("The reset code is invalid or has expired.");
        await _users.UpdatePasswordAsync(user.Id, _passwords.Hash(request.NewPassword), ct);
        return OperationResult.Success("Password updated. You can now log in.");
    }

    public async Task<OperationResult> ChangePasswordAsync(long userId, ChangePasswordRequest request, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct);
        if (user is null) return OperationResult.Failure("Account not found.");
        if (!_passwords.Verify(request.CurrentPassword, user.PasswordHash)) return OperationResult.Failure("Current password is incorrect.");
        if (request.CurrentPassword == request.NewPassword) return OperationResult.Failure("The new password must be different from the current password.");
        await _users.UpdatePasswordAsync(userId, _passwords.Hash(request.NewPassword), ct);
        return OperationResult.Success("Password changed successfully.");
    }
}
