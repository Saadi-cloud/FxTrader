using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
namespace TahirFxTrader.Web.Areas.Admin.Controllers;
[Area("Admin"), Authorize(Roles = "Admin")]
public sealed class DashboardController : Controller
{
    private readonly IAdminService _service;
    public DashboardController(IAdminService service) => _service = service;
    public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetDashboardAsync(ct));
}
