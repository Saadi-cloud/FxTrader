using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Authorization;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Areas.Admin.Controllers;
[Area("Admin"), Authorize(Roles = "Admin")]
public sealed class UsersController : Controller
{
    private readonly IAdminService _service;
    private readonly IAuthService _auth;
    public UsersController(IAdminService service, IAuthService auth) { _service = service; _auth = auth; }
    public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetUsersAsync(ct));
    [HttpGet] public IActionResult Create() => View(new RegisterRequest());
    [HttpPost]
    public async Task<IActionResult> Create(RegisterRequest model, CancellationToken ct)
    {
        if (!ModelState.IsValid) return View(model);
        var result = await _auth.RegisterAsync(model, ct);
        if (!result.Succeeded) { ModelState.AddModelError(string.Empty, result.Message); return View(model); }
        TempData["Success"] = result.Message;
        return RedirectToAction(nameof(Index));
    }
    [HttpGet] public async Task<IActionResult> Edit(long id, CancellationToken ct)
    { var model = await _service.GetUserAsync(id, ct); if (model is null) return NotFound(); ViewBag.AllPermissions = Permissions.UserPermissions; return View(model); }
    [HttpPost]
    public async Task<IActionResult> Edit(AdminUserEditModel model, CancellationToken ct)
    {
        ViewBag.AllPermissions = Permissions.UserPermissions;
        if (!ModelState.IsValid) return View(model);
        var result = await _service.UpdateUserAsync(model, User.UserId(), ct);
        if (!result.Succeeded) { ModelState.AddModelError(string.Empty, result.Message); return View(model); }
        TempData["Success"] = result.Message; return RedirectToAction(nameof(Index));
    }
}
