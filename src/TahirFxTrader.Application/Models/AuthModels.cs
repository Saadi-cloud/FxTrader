using System.ComponentModel.DataAnnotations;
namespace TahirFxTrader.Application.Models;
public sealed class LoginRequest
{
    [Required, EmailAddress] public string Email { get; set; } = string.Empty;
    [Required] public string Password { get; set; } = string.Empty;
    public bool RememberMe { get; set; }
}
public sealed class RegisterRequest
{
    [Required, StringLength(120, MinimumLength = 2)] public string FullName { get; set; } = string.Empty;
    [Required, StringLength(80)] public string Country { get; set; } = string.Empty;
    [Required, Phone, StringLength(30, MinimumLength = 6)] public string PhoneNumber { get; set; } = string.Empty;
    [Required, EmailAddress] public string Email { get; set; } = string.Empty;
    [StringLength(40)] public string? ReferralCode { get; set; }
    [Required, StringLength(100, MinimumLength = 8)] public string Password { get; set; } = string.Empty;
    [Required, Compare(nameof(Password))] public string ConfirmPassword { get; set; } = string.Empty;
}
public sealed class VerifyEmailRequest
{
    [Required, EmailAddress] public string Email { get; set; } = string.Empty;
    [Required, StringLength(6, MinimumLength = 6)] public string Code { get; set; } = string.Empty;
}
public sealed class ForgotPasswordRequest { [Required, EmailAddress] public string Email { get; set; } = string.Empty; }
public sealed class ResetPasswordRequest
{
    [Required, EmailAddress] public string Email { get; set; } = string.Empty;
    [Required, StringLength(6, MinimumLength = 6)] public string Code { get; set; } = string.Empty;
    [Required, StringLength(100, MinimumLength = 8)] public string NewPassword { get; set; } = string.Empty;
    [Required, Compare(nameof(NewPassword))] public string ConfirmPassword { get; set; } = string.Empty;
}
public sealed record AuthenticatedUser(long Id, string UserTraceId, string FullName, string Email, string RoleName, IReadOnlyCollection<string> Permissions);

public sealed class ChangePasswordRequest
{
    [Required] public string CurrentPassword { get; set; } = string.Empty;
    [Required, StringLength(100, MinimumLength = 8)] public string NewPassword { get; set; } = string.Empty;
    [Required, Compare(nameof(NewPassword))] public string ConfirmPassword { get; set; } = string.Empty;
}
