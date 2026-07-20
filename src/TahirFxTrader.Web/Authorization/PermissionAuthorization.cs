using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;
namespace TahirFxTrader.Web.Authorization;
public static class Permissions
{
    public const string DepositCreate = "Deposit.Create";
    public const string DepositHistory = "Deposit.History";
    public const string WithdrawalCreate = "Withdrawal.Create";
    public const string WithdrawalHistory = "Withdrawal.History";
    public const string StatementView = "Statement.View";
    public static readonly string[] UserPermissions = { DepositCreate, DepositHistory, WithdrawalCreate, WithdrawalHistory, StatementView };
}
public sealed record PermissionRequirement(string Permission) : IAuthorizationRequirement;
public sealed class PermissionAuthorizationHandler : AuthorizationHandler<PermissionRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, PermissionRequirement requirement)
    {
        if (context.User.IsInRole("Admin") || context.User.Claims.Any(c => c.Type == "permission" && string.Equals(c.Value, requirement.Permission, StringComparison.OrdinalIgnoreCase)))
            context.Succeed(requirement);
        return Task.CompletedTask;
    }
}
public sealed class PermissionPolicyProvider : IAuthorizationPolicyProvider
{
    private const string Prefix = "Permission:";
    private readonly DefaultAuthorizationPolicyProvider _fallback;
    public PermissionPolicyProvider(IOptions<AuthorizationOptions> options) => _fallback = new DefaultAuthorizationPolicyProvider(options);
    public Task<AuthorizationPolicy> GetDefaultPolicyAsync() => _fallback.GetDefaultPolicyAsync();
    public Task<AuthorizationPolicy?> GetFallbackPolicyAsync() => _fallback.GetFallbackPolicyAsync();
    public Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        if (!policyName.StartsWith(Prefix, StringComparison.OrdinalIgnoreCase)) return _fallback.GetPolicyAsync(policyName);
        var permission = policyName[Prefix.Length..];
        var policy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().AddRequirements(new PermissionRequirement(permission)).Build();
        return Task.FromResult<AuthorizationPolicy?>(policy);
    }
}

public sealed class DatabaseClaimsTransformation : Microsoft.AspNetCore.Authentication.IClaimsTransformation
{
    private const string Marker = "database_claims_refreshed";
    private readonly TahirFxTrader.Application.Interfaces.Repositories.IUserRepository _users;
    public DatabaseClaimsTransformation(TahirFxTrader.Application.Interfaces.Repositories.IUserRepository users) => _users = users;
    public async Task<System.Security.Claims.ClaimsPrincipal> TransformAsync(System.Security.Claims.ClaimsPrincipal principal)
    {
        if (principal.Identity is not System.Security.Claims.ClaimsIdentity identity || !identity.IsAuthenticated || identity.HasClaim(Marker, "1")) return principal;
        var idValue = identity.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (!long.TryParse(idValue, out var userId)) return principal;
        var user = await _users.GetByIdAsync(userId);
        if (user is null) return principal;
        foreach (var claim in identity.FindAll(System.Security.Claims.ClaimTypes.Role).ToList()) identity.RemoveClaim(claim);
        foreach (var claim in identity.FindAll(System.Security.Claims.ClaimTypes.Name).ToList()) identity.RemoveClaim(claim);
        foreach (var claim in identity.FindAll(System.Security.Claims.ClaimTypes.Email).ToList()) identity.RemoveClaim(claim);
        foreach (var claim in identity.FindAll("permission").ToList()) identity.RemoveClaim(claim);
        identity.AddClaim(new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Role, user.RoleName));
        identity.AddClaim(new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Name, user.FullName));
        identity.AddClaim(new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Email, user.Email));
        var permissions = await _users.GetEffectivePermissionsAsync(userId);
        foreach (var permission in permissions) identity.AddClaim(new System.Security.Claims.Claim("permission", permission));
        identity.AddClaim(new System.Security.Claims.Claim(Marker, "1"));
        return principal;
    }
}
