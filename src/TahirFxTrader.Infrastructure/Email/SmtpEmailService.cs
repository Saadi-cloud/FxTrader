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
    => $@"
    <div style='font-family:Segoe UI,Arial,sans-serif;background:#F4F6F8;padding:40px 0;'>
      <table role='presentation' width='100%' cellpadding='0' cellspacing='0'>
        <tr>
          <td align='center'>
            <table role='presentation' width='480' cellpadding='0' cellspacing='0'
                   style='background:#FFFFFF;border-radius:12px;overflow:hidden;
                          box-shadow:0 2px 10px rgba(0,0,0,0.06);'>

              <!-- Header -->
              <tr>
                <td style='background:#0B0E11;padding:24px 32px;text-align:center;'>
                  <span style='font-size:22px;font-weight:700;color:#F0B90B;letter-spacing:1px;'>
                    OLX Trade
                  </span>
                </td>
              </tr>

              <!-- Body -->
              <tr>
                <td style='padding:36px 32px 24px 32px;'>
                  <h2 style='margin:0 0 12px 0;color:#1E2329;font-size:20px;font-weight:600;'>
                    Withdrawal Verification
                  </h2>
                  <p style='margin:0 0 20px 0;color:#4B5563;font-size:15px;line-height:1.6;'>
                    Hello {WebUtility.HtmlEncode(name)}, use the code below to verify your withdrawal request.
                  </p>

                  <!-- Code box -->
                  <div style='text-align:center;margin:28px 0;'>
                    <div style='display:inline-block;background:#F8F9FA;border:1px solid #F0B90B;
                                border-radius:10px;padding:16px 28px;'>
                      <span style='font-size:28px;font-weight:700;letter-spacing:6px;color:#1E2329;'>
                        {WebUtility.HtmlEncode(code)}
                      </span>
                    </div>
                  </div>

                  <!-- Details -->
                  <table role='presentation' width='100%' cellpadding='0' cellspacing='0'
                         style='background:#F8F9FA;border-radius:8px;margin:8px 0 20px 0;'>
                    <tr>
                      <td style='padding:14px 18px;font-size:14px;color:#4B5563;border-bottom:1px solid #EDEFF2;'>
                        Amount
                      </td>
                      <td style='padding:14px 18px;font-size:14px;color:#1E2329;font-weight:600;text-align:right;border-bottom:1px solid #EDEFF2;'>
                        ${amount:N2}
                      </td>
                    </tr>
                    <tr>
                      <td style='padding:14px 18px;font-size:14px;color:#4B5563;'>
                        Wallet
                      </td>
                      <td style='padding:14px 18px;font-size:14px;color:#1E2329;font-weight:600;text-align:right;'>
                        {WebUtility.HtmlEncode(walletSource)}
                      </td>
                    </tr>
                  </table>

                  <p style='margin:0 0 16px 0;color:#F6465D;font-weight:600;font-size:14px;'>
                    ⓘ This code expires in 2 minutes.
                  </p>

                  <p style='margin:0;color:#9CA3AF;font-size:12px;line-height:1.6;'>
                    Never share this code with anyone. OLX Trade support will never ask for your withdrawal OTP.
                  </p>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style='padding:20px 32px;background:#FAFAFA;border-top:1px solid #F0F0F0;text-align:center;'>
                  <p style='margin:0;color:#9CA3AF;font-size:12px;'>
                    © {DateTime.Now.Year} OLX Trade. All rights reserved.
                  </p>
                  <p style='margin:4px 0 0 0;color:#9CA3AF;font-size:12px;'>
                    This is an automated message, please do not reply.
                  </p>
                </td>
              </tr>

            </table>
          </td>
        </tr>
      </table>
    </div>";
    //private static string WithdrawalTemplate(string name, string code, decimal amount, string walletSource)
    //    => $"<div style='font-family:Arial;background:#0B0E11;color:#EAECEF;padding:28px'>" +
    //       $"<div style='max-width:520px;margin:auto;background:#181A20;border:1px solid #2B3139;border-radius:16px;padding:28px'>" +
    //       $"<h2 style='color:#F0B90B;margin-top:0'>OLX Trade</h2>" +
    //       $"<p>Hello {WebUtility.HtmlEncode(name)},</p>" +
    //       $"<p>Use this code to verify your withdrawal request.</p>" +
    //       $"<div style='font-size:32px;font-weight:700;letter-spacing:9px;background:#0B0E11;border:1px solid #F0B90B;padding:18px;border-radius:10px;text-align:center'>{WebUtility.HtmlEncode(code)}</div>" +
    //       $"<p style='margin-top:20px'><strong>Amount:</strong> ${amount:N2}<br><strong>Wallet:</strong> {WebUtility.HtmlEncode(walletSource)}</p>" +
    //       $"<p style='color:#F6465D;font-weight:700'>This code expires in 2 minutes.</p>" +
    //       $"<p style='color:#848E9C;font-size:13px'>Never share this code. OLX Trade support will never ask for your withdrawal OTP.</p>" +
    //       $"</div></div>";

    //private static string Template(string name, string heading, string code, string note)
    //    => $"<div style='font-family:Arial;background:#0B0E11;color:#EAECEF;padding:28px'>" +
    //       $"<h2 style='color:#F0B90B'>OLX Trade</h2>" +
    //       $"<p>Hello {WebUtility.HtmlEncode(name)},</p>" +
    //       $"<p>{WebUtility.HtmlEncode(heading)}:</p>" +
    //       $"<div style='font-size:30px;font-weight:700;letter-spacing:8px;background:#1E2329;" +
    //       $"padding:18px;border-radius:10px;display:inline-block'>{WebUtility.HtmlEncode(code)}</div>" +
    //       $"<p style='color:#848E9C'>{WebUtility.HtmlEncode(note)}</p></div>";
    private static string Template(string name, string heading, string code, string note)
    => $@"
    <div style='font-family:Segoe UI,Arial,sans-serif;background:#F4F6F8;padding:40px 0;'>
      <table role='presentation' width='100%' cellpadding='0' cellspacing='0'>
        <tr>
          <td align='center'>
            <table role='presentation' width='480' cellpadding='0' cellspacing='0'
                   style='background:#FFFFFF;border-radius:12px;overflow:hidden;
                          box-shadow:0 2px 10px rgba(0,0,0,0.06);'>

              <!-- Header -->
              <tr>
                <td style='background:#0B0E11;padding:24px 32px;text-align:center;'>
                  <span style='font-size:22px;font-weight:700;color:#F0B90B;letter-spacing:1px;'>
                    OLX Trade
                  </span>
                </td>
              </tr>

              <!-- Body -->
              <tr>
                <td style='padding:36px 32px 24px 32px;'>
                  <h2 style='margin:0 0 12px 0;color:#1E2329;font-size:20px;font-weight:600;'>
                    Welcome, {WebUtility.HtmlEncode(name)} 👋
                  </h2>
                  <p style='margin:0 0 20px 0;color:#4B5563;font-size:15px;line-height:1.6;'>
                    {WebUtility.HtmlEncode(heading)}
                  </p>

                  <!-- Code / Highlight box -->
                  <div style='text-align:center;margin:28px 0;'>
                    <div style='display:inline-block;background:#F8F9FA;border:1px solid #E5E7EB;
                                border-radius:10px;padding:16px 28px;'>
                      <span style='font-size:28px;font-weight:700;letter-spacing:6px;color:#1E2329;'>
                        {WebUtility.HtmlEncode(code)}
                      </span>
                    </div>
                  </div>

                  <p style='margin:0;color:#6B7280;font-size:13px;line-height:1.6;'>
                    {WebUtility.HtmlEncode(note)}
                  </p>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style='padding:20px 32px;background:#FAFAFA;border-top:1px solid #F0F0F0;text-align:center;'>
                  <p style='margin:0;color:#9CA3AF;font-size:12px;'>
                    © {DateTime.Now.Year} OLX Trade. All rights reserved.
                  </p>
                  <p style='margin:4px 0 0 0;color:#9CA3AF;font-size:12px;'>
                    This is an automated message, please do not reply.
                  </p>
                </td>
              </tr>

            </table>
          </td>
        </tr>
      </table>
    </div>";
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
