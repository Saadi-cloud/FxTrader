using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Web.Models;
namespace TahirFxTrader.Web.Controllers;

[AllowAnonymous]
[Route("invite")]
public sealed class ReferralController : Controller
{
    private static readonly Regex TracePattern = new(@"^USR-\d{8}-\d{6}$", RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private readonly IDashboardService _dashboard;
    private readonly IConfiguration _configuration;

    public ReferralController(IDashboardService dashboard, IConfiguration configuration)
    {
        _dashboard = dashboard;
        _configuration = configuration;
    }

    [HttpGet("{code}", Name = "ReferralInvite")]
    [ResponseCache(Duration = 300, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> Index(string code, CancellationToken ct)
    {
        code = (code ?? string.Empty).Trim().ToUpperInvariant();
        if (!TracePattern.IsMatch(code)) return NotFound();

        var registerPath = Url.Action("Register", "Auth", new { referral = code })
            ?? $"/account/register?referral={Uri.EscapeDataString(code)}";
        var invitePath = Url.RouteUrl("ReferralInvite", new { code })
            ?? $"/invite/{Uri.EscapeDataString(code)}";

        var registerUrl = ToPublicAbsoluteUrl(registerPath);
        var canonicalUrl = ToPublicAbsoluteUrl(invitePath);
        var previewVersion = _configuration["Site:ReferralPreviewVersion"]?.Trim();
        if (string.IsNullOrWhiteSpace(previewVersion)) previewVersion = "20260718-3";

        // The version query forces social platforms to refresh an older cached card.
        var shareUrl = $"{canonicalUrl}?preview={Uri.EscapeDataString(previewVersion)}";
        var shareImage = ToPublicAbsoluteUrl($"/images/referral/olx-referral-og.jpg?v={Uri.EscapeDataString(previewVersion)}");

        decimal percentage = 5;
        try
        {
            var configuredPercentage = await _dashboard.GetReferralCommissionPercentAsync(ct);
            if (configuredPercentage > 0) percentage = configuredPercentage;
        }
        catch
        {
            // Keep the public invite page available during a rolling database upgrade.
        }

        Response.Headers["X-Robots-Tag"] = "index, follow, max-image-preview:large";

        return View(new ReferralLandingViewModel
        {
            ReferralCode = code,
            RegisterUrl = registerUrl,
            ShareUrl = shareUrl,
            CanonicalUrl = canonicalUrl,
            ShareImageUrl = shareImage,
            CommissionPercent = percentage
        });
    }

    private string ToPublicAbsoluteUrl(string pathOrUrl)
    {
        if (Uri.TryCreate(pathOrUrl, UriKind.Absolute, out var absolute))
            return absolute.ToString();

        var configuredBaseUrl = _configuration["Site:PublicBaseUrl"]?.Trim().TrimEnd('/');
        if (Uri.TryCreate(configuredBaseUrl, UriKind.Absolute, out var configuredBase))
            return new Uri(configuredBase, pathOrUrl.StartsWith('/') ? pathOrUrl : "/" + pathOrUrl).ToString();

        return $"{Request.Scheme}://{Request.Host}{Request.PathBase}{(pathOrUrl.StartsWith('/') ? pathOrUrl : "/" + pathOrUrl)}";
    }
}
