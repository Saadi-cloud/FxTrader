using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
namespace TahirFxTrader.Web.Controllers;
[AllowAnonymous]
[EnableRateLimiting("auth")]
[Route("account")]
public sealed class AuthController : Controller
{
    private readonly IAuthService _auth;
    public AuthController(IAuthService auth) => _auth = auth;
    [HttpGet("login")] public IActionResult Login(string? returnUrl = null) { ViewBag.ReturnUrl = returnUrl; return View(new LoginRequest()); }
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest model, string? returnUrl = null, CancellationToken ct = default)
    {
        if (!ModelState.IsValid) return View(model);
        var result = await _auth.LoginAsync(model, ct);
        if (!result.Succeeded || result.Data is null) { ModelState.AddModelError(string.Empty, result.Message); return View(model); }
        var user = result.Data;
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()), new("user_trace_id", user.UserTraceId), new(ClaimTypes.Name, user.FullName), new(ClaimTypes.Email, user.Email), new(ClaimTypes.Role, user.RoleName)
        };
        claims.AddRange(user.Permissions.Select(x => new Claim("permission", x)));
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme));
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal, new AuthenticationProperties
        {
            IsPersistent = model.RememberMe,
            ExpiresUtc = DateTimeOffset.UtcNow.Add(model.RememberMe ? TimeSpan.FromDays(30) : TimeSpan.FromHours(8))
        });
        if (!string.IsNullOrWhiteSpace(returnUrl) && Url.IsLocalUrl(returnUrl)) return LocalRedirect(returnUrl);
        return user.RoleName.Equals("Admin", StringComparison.OrdinalIgnoreCase) ? RedirectToAction("Index", "Dashboard", new { area = "Admin" }) : RedirectToAction("Index", "Dashboard");
    }
    [HttpGet("register")] public IActionResult Register(string? referral = null) => View(new RegisterRequest { ReferralCode = string.IsNullOrWhiteSpace(referral) ? null : referral.Trim().ToUpperInvariant() });
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest model, CancellationToken ct)
    {
        if (!ModelState.IsValid) return View(model);
        var result = await _auth.RegisterAsync(model, ct);
        if (!result.Succeeded || result.Data is null) { ModelState.AddModelError(string.Empty, result.Message); return View(model); }
        TempData["Success"] = result.Message;
        return RedirectToAction(nameof(VerifyEmail), new { email = result.Data });
    }
    [HttpGet("verify-email")] public IActionResult VerifyEmail(string email) => View(new VerifyEmailRequest { Email = email });
    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail(VerifyEmailRequest model, CancellationToken ct)
    {
        if (!ModelState.IsValid) return View(model);
        var result = await _auth.VerifyEmailAsync(model, ct);
        if (!result.Succeeded) { ModelState.AddModelError(string.Empty, result.Message); return View(model); }
        TempData["Success"] = result.Message; return RedirectToAction(nameof(Login));
    }
    [HttpPost("resend-verification")]
    public async Task<IActionResult> ResendVerification(string email, CancellationToken ct)
    { var result = await _auth.ResendVerificationAsync(email, ct); TempData[result.Succeeded ? "Success" : "Error"] = result.Message; return RedirectToAction(nameof(VerifyEmail), new { email }); }
    [HttpGet("forgot-password")] public IActionResult ForgotPassword() => View(new ForgotPasswordRequest());
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest model, CancellationToken ct)
    { if (!ModelState.IsValid) return View(model); var result = await _auth.ForgotPasswordAsync(model, ct); TempData["Success"] = result.Message; return RedirectToAction(nameof(ResetPassword), new { email = model.Email }); }
    [HttpGet("reset-password")] public IActionResult ResetPassword(string email) => View(new ResetPasswordRequest { Email = email });
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest model, CancellationToken ct)
    { if (!ModelState.IsValid) return View(model); var result = await _auth.ResetPasswordAsync(model, ct); if (!result.Succeeded) { ModelState.AddModelError(string.Empty, result.Message); return View(model); } TempData["Success"] = result.Message; return RedirectToAction(nameof(Login)); }
    [Authorize, HttpPost("logout")]
    public async Task<IActionResult> Logout() { await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme); return RedirectToAction(nameof(Login)); }
    [HttpGet("access-denied")] public IActionResult AccessDenied() => View();
}
