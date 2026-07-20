using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Areas.Admin.Controllers;
[Area("Admin"), Authorize(Roles = "Admin")]
public sealed class ReferralsController : Controller
{
    private readonly IAdminService _service;
    public ReferralsController(IAdminService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetReferralAdminAsync(ct));

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> SaveWelcomeBonus(WelcomeBonusSettingsRequest model, CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            TempData["Error"] = "Enter a welcome bonus percentage between 0 and 100.";
            return RedirectToAction(nameof(Index));
        }
        var result = await _service.SaveWelcomeBonusPercentAsync(model, User.UserId(), ct);
        TempData[result.Succeeded ? "Success" : "Error"] = result.Message;
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> SaveReferralCommission(ReferralCommissionSettingsRequest model, CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            TempData["Error"] = "Enter a referral commission percentage between 0 and 100.";
            return RedirectToAction(nameof(Index));
        }
        var result = await _service.SaveReferralCommissionPercentAsync(model, User.UserId(), ct);
        TempData[result.Succeeded ? "Success" : "Error"] = result.Message;
        return RedirectToAction(nameof(Index));
    }
}
