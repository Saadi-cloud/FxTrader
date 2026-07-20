using System.Net;
using System.Net.Mail;
using System.Text;
using Microsoft.Extensions.Options;
using TahirFxTrader.Application.Interfaces.Services;

namespace TahirFxTrader.Infrastructure.Email;

public sealed class SmtpEmailService : IEmailService
{
    private readonly SmtpOptions _options;

    public SmtpEmailService(IOptions<SmtpOptions> options)
    {
        _options = options.Value;
        ValidateOptions(_options);
    }

    public Task SendVerificationCodeAsync(
        string email,
        string fullName,
        string code,
        CancellationToken ct = default)
        => SendAsync(
            email,
            "Verify your OLX Trade account",
            Template(
                fullName,
                "Email verification code",
                code,
                "This code expires in 15 minutes."),
            ct);

    public Task SendPasswordResetCodeAsync(
        string email,
        string fullName,
        string code,
        CancellationToken ct = default)
        => SendAsync(
            email,
            "Reset your OLX Trade password",
            Template(
                fullName,
                "Password reset code",
                code,
                "This code expires in 15 minutes. Ignore this message if you did not request a reset."),
            ct);

    public Task SendWithdrawalVerificationCodeAsync(
        string email,
        string fullName,
        string code,
        decimal amount,
        string walletSource,
        CancellationToken ct = default)
        => SendAsync(
            email,
            "Verify your OLX Trade withdrawal",
            WithdrawalTemplate(fullName, code, amount, walletSource),
            ct);

    public Task SendTransactionStatusAsync(
        string email,
        string fullName,
        string referenceNo,
        string status,
        CancellationToken ct = default)
        => SendAsync(
            email,
            $"Transaction {referenceNo}: {status}",
            $"<div style='font-family:Arial;background:#0B0E11;color:#EAECEF;padding:28px'>" +
            $"<h2 style='color:#F0B90B'>OLX Trade</h2>" +
            $"<p>Hello {WebUtility.HtmlEncode(fullName)},</p>" +
            $"<p>Your transaction <strong>{WebUtility.HtmlEncode(referenceNo)}</strong> " +
            $"is now <strong>{WebUtility.HtmlEncode(status)}</strong>.</p></div>",
            ct);

    private static string WithdrawalTemplate(string name, string code, decimal amount, string walletSource)
        => $"<div style='font-family:Arial;background:#0B0E11;color:#EAECEF;padding:28px'>" +
           $"<div style='max-width:520px;margin:auto;background:#181A20;border:1px solid #2B3139;border-radius:16px;padding:28px'>" +
           $"<h2 style='color:#F0B90B;margin-top:0'>OLX Trade</h2>" +
           $"<p>Hello {WebUtility.HtmlEncode(name)},</p>" +
           $"<p>Use this code to verify your withdrawal request.</p>" +
           $"<div style='font-size:32px;font-weight:700;letter-spacing:9px;background:#0B0E11;border:1px solid #F0B90B;padding:18px;border-radius:10px;text-align:center'>{WebUtility.HtmlEncode(code)}</div>" +
           $"<p style='margin-top:20px'><strong>Amount:</strong> ${amount:N2}<br><strong>Wallet:</strong> {WebUtility.HtmlEncode(walletSource)}</p>" +
           $"<p style='color:#F6465D;font-weight:700'>This code expires in 2 minutes.</p>" +
           $"<p style='color:#848E9C;font-size:13px'>Never share this code. OLX Trade support will never ask for your withdrawal OTP.</p>" +
           $"</div></div>";

    private static string Template(string name, string heading, string code, string note)
        => $"<div style='font-family:Arial;background:#0B0E11;color:#EAECEF;padding:28px'>" +
           $"<h2 style='color:#F0B90B'>OLX Trade</h2>" +
           $"<p>Hello {WebUtility.HtmlEncode(name)},</p>" +
           $"<p>{WebUtility.HtmlEncode(heading)}:</p>" +
           $"<div style='font-size:30px;font-weight:700;letter-spacing:8px;background:#1E2329;" +
           $"padding:18px;border-radius:10px;display:inline-block'>{WebUtility.HtmlEncode(code)}</div>" +
           $"<p style='color:#848E9C'>{WebUtility.HtmlEncode(note)}</p></div>";

    private async Task SendAsync(
        string to,
        string subject,
        string html,
        CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();

        using var client = new SmtpClient(_options.Host, _options.Port)
        {
            EnableSsl = _options.EnableSsl,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(_options.Username, _options.Password),
            DeliveryMethod = SmtpDeliveryMethod.Network,
            Timeout = 30000
        };

        using var message = new MailMessage
        {
            From = new MailAddress(_options.FromEmail, _options.FromName, Encoding.UTF8),
            Subject = subject,
            SubjectEncoding = Encoding.UTF8,
            Body = html,
            BodyEncoding = Encoding.UTF8,
            IsBodyHtml = true
        };

        message.To.Add(new MailAddress(to));
        await client.SendMailAsync(message, ct);
    }

    private static void ValidateOptions(SmtpOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.Host))
            throw new InvalidOperationException("SMTP Host is missing in appsettings.json.");
        if (options.Port <= 0)
            throw new InvalidOperationException("SMTP Port is invalid in appsettings.json.");
        if (string.IsNullOrWhiteSpace(options.Username))
            throw new InvalidOperationException("SMTP Username is missing in appsettings.json.");
        if (string.IsNullOrWhiteSpace(options.Password))
            throw new InvalidOperationException("SMTP Password is missing in appsettings.json.");
        if (string.IsNullOrWhiteSpace(options.FromEmail))
            throw new InvalidOperationException("SMTP FromEmail is missing in appsettings.json.");
    }
}
