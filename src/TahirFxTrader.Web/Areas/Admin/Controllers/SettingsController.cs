using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Areas.Admin.Controllers;
[Area("Admin"), Authorize(Roles = "Admin")]
public sealed class SettingsController : Controller
{
    private readonly IAdminService _service;
    public SettingsController(IAdminService service) => _service = service;
    [HttpGet] public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetSettingsAsync(ct));
    [HttpPost] public async Task<IActionResult> Index(SystemSettingsModel model, CancellationToken ct)
    { if (!ModelState.IsValid) return View(model); var r = await _service.SaveSettingsAsync(model, User.UserId(), ct); if (!r.Succeeded) { ModelState.AddModelError(string.Empty, r.Message); return View(model); } TempData["Success"] = r.Message; return RedirectToAction(nameof(Index)); }
}
