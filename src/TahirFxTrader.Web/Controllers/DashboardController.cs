using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Controllers;
[Authorize]
public sealed class DashboardController : Controller
{
    private readonly IDashboardService _service;
    private readonly IConfiguration _configuration;

    public DashboardController(IDashboardService service, IConfiguration configuration)
    {
        _service = service;
        _configuration = configuration;
    }

    public async Task<IActionResult> Index(CancellationToken ct)
    {
        var model = await _service.GetAsync(User.UserId(), ct);

        var registerPath = Url.Action("Register", "Auth", new { referral = model.UserTraceId })
            ?? $"/account/register?referral={Uri.EscapeDataString(model.UserTraceId)}";
        var invitePath = Url.RouteUrl("ReferralInvite", new { code = model.UserTraceId })
            ?? $"/invite/{Uri.EscapeDataString(model.UserTraceId)}";

        model.ReferralRegisterUrl = ToPublicAbsoluteUrl(registerPath);
        var inviteUrl = ToPublicAbsoluteUrl(invitePath);
        var previewVersion = _configuration["Site:ReferralPreviewVersion"]?.Trim();
        if (string.IsNullOrWhiteSpace(previewVersion)) previewVersion = "20260718-3";
        model.ReferralLink = $"{inviteUrl}?preview={Uri.EscapeDataString(previewVersion)}";

        return View(model);
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
