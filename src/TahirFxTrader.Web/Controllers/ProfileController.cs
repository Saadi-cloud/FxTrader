using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Controllers;
[Authorize]
public sealed class ProfileController : Controller
{
    private readonly IAuthService _auth;
    public ProfileController(IAuthService auth) => _auth = auth;
    [HttpGet] public IActionResult Security() => View(new ChangePasswordRequest());
    [HttpPost]
    public async Task<IActionResult> Security(ChangePasswordRequest model, CancellationToken ct)
    {
        if (!ModelState.IsValid) return View(model);
        var result = await _auth.ChangePasswordAsync(User.UserId(), model, ct);
        if (!result.Succeeded) { ModelState.AddModelError(string.Empty, result.Message); return View(model); }
        TempData["Success"] = result.Message;
        return RedirectToAction(nameof(Security));
    }
}
