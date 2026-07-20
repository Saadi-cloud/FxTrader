using System.Security.Claims;
namespace TahirFxTrader.Web.Extensions;
public static class ClaimsPrincipalExtensions
{
    public static long UserId(this ClaimsPrincipal principal)
    {
        var value = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        return long.TryParse(value, out var id) ? id : throw new UnauthorizedAccessException("User identifier is unavailable.");
    }
    public static string Initials(this ClaimsPrincipal principal)
    {
        var name = principal.Identity?.Name ?? "User";
        return string.Concat(name.Split(' ', StringSplitOptions.RemoveEmptyEntries).Take(2).Select(x => char.ToUpperInvariant(x[0])));
    }
}
