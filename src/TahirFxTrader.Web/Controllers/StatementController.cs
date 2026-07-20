using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Web.Authorization;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Controllers;
[Authorize(Policy = "Permission:" + Permissions.StatementView)]
public sealed class StatementController : Controller
{
    private readonly IDashboardService _service;
    public StatementController(IDashboardService service) => _service = service;
    public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetStatementAsync(User.UserId(), ct));
}
