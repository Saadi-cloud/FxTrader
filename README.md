# OLX Trade

A layered ASP.NET Core MVC project for user management, manual deposits, manual withdrawals, wallet balances, transaction approvals, configurable payment methods, and admin-controlled page access.

## Architecture

```text
TahirFxTrader.Web
  Controllers / Razor Views / Cookie Authentication
            ↓
TahirFxTrader.Application
  IService → Service → IRepository contracts
            ↓
TahirFxTrader.Infrastructure
  ADO.NET repositories / SMTP / file storage / password security
            ↓
SQL Server stored procedures
```

The C# repositories execute stored procedures only. Financial balance changes are performed inside SQL Server transactions with row locking so a deposit cannot be credited twice and a withdrawal cannot be completed or released twice.

## Included modules

- Registration, login, logout, secure PBKDF2 password hashing
- Six-digit email verification code
- Forgot-password and reset-code email flow
- Authenticated change-password page for users and administrators
- Cookie authentication with database-refreshed roles and permissions
- Admin user management
- Active, pending, suspended, and blocked account statuses
- Admin controls for deposit/withdraw eligibility
- Per-user withdrawal minimum, maximum, and fee overrides
- Per-user page/form permissions
- Configurable JazzCash, EasyPaisa, bank, crypto, and custom payment methods
- Deposit screenshot upload and duplicate transaction-reference protection
- Admin deposit approval/rejection with atomic wallet credit
- Withdrawal balance reservation, processing, completion, and rejection
- Automatic release of reserved funds on rejection
- Global and method-specific withdrawal fees and limits
- Wallet ledger and user statement
- Admin audit log table
- Responsive mobile-first dark/gold frontend based on the supplied HTML/CSS

## Requirements

- .NET 8 SDK
- SQL Server 2019 or newer, or a compatible Azure SQL database
- SQL Server Management Studio or Azure Data Studio
- SMTP credentials from a service such as SendGrid, Amazon SES, Mailgun, Postmark, or another authenticated SMTP provider

## Database setup

1. Open `Database/FXTraderDb.sql` in SQL Server Management Studio.
2. Execute the complete script.
3. It creates `TahirFxTraderDb`, all tables, indexes, seed data, sequences, and stored procedures.
4. Update the connection string in `src/TahirFxTrader.Web/appsettings.json`.

Default local connection string:

```json
"Server=.;Database=TahirFxTraderDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=False"
```

For SQL authentication:

```json
"Server=YOUR_SERVER;Database=TahirFxTraderDb;User Id=YOUR_USER;Password=YOUR_PASSWORD;TrustServerCertificate=True;MultipleActiveResultSets=False"
```

## SMTP setup

Update the `Smtp` section in `src/TahirFxTrader.Web/appsettings.json`:

```json
"Smtp": {
  "Host": "smtp.sendgrid.net",
  "Port": 587,
  "EnableSsl": true,
  "Username": "apikey",
  "Password": "YOUR_SMTP_API_KEY",
  "FromEmail": "verified-sender@yourdomain.com",
  "FromName": "OLX Trade"
}
```

Do not commit production passwords. In production, use environment variables, .NET user secrets, Azure Key Vault, AWS Secrets Manager, or your host's secret manager.

Environment variable examples:

```text
ConnectionStrings__DefaultConnection
Smtp__Host
Smtp__Port
Smtp__Username
Smtp__Password
Smtp__FromEmail
Smtp__FromName
```

## Run the application

From the project root:

```bash
dotnet restore
dotnet build TahirFxTrader.sln
dotnet run --project src/TahirFxTrader.Web
```

Open the URL shown in the terminal, normally `https://localhost:7080` or `http://localhost:5080`.

## Seed administrator

```text
Email:    admin@fxtrader.local
Password: Admin@123
```

Change this password immediately after first deployment. The seed account is already email-verified and active.

## Transaction rules

### Deposit

1. User selects an active deposit method.
2. User enters amount, sender account, transaction reference, and uploads payment proof.
3. Request is stored as Pending.
4. Admin reviews the screenshot and transaction details.
5. Approval uses a database transaction and row lock.
6. The wallet is credited once, a visible ledger entry is created, and the deposit becomes Approved.
7. Repeated approval attempts are refused.

### Withdrawal

1. User selects an active withdrawal method and enters destination details.
2. SQL Server calculates the effective minimum, maximum, and fee using user override, payment-method rule, and global setting priority.
3. The full requested amount moves from Available to Held immediately.
4. A hidden ledger debit is created while the request is pending.
5. Admin manually sends the net amount and records the payment reference.
6. Completion removes the amount from Held and exposes the permanent ledger debit.
7. Rejection returns the amount from Held to Available and removes the hidden debit.
8. Repeated completion or rejection attempts are refused.

## Production checklist

- Replace all seeded JazzCash, EasyPaisa, bank, and crypto account details.
- Configure real SMTP credentials and a verified sender domain.
- Change the seed administrator password.
- Use an HTTPS certificate and set the authentication cookie to Always Secure behind your reverse proxy.
- Restrict upload directories from script execution at the web-server level.
- Use a dedicated least-privilege SQL login with EXECUTE permission on the stored procedures and required table access only.
- Configure database backups and retention.
- Add malware scanning or object storage for screenshots if transaction volume is high.
- Review privacy, AML/KYC, financial, tax, and money-transmission obligations for the countries where the application will operate.

## Important source folders

```text
Database/FXTraderDb.sql
src/TahirFxTrader.Domain
src/TahirFxTrader.Application
src/TahirFxTrader.Infrastructure
src/TahirFxTrader.Web
```

## Development port startup fix

The default Visual Studio profile is now **TahirFxTrader.Web (HTTP)** and runs at:

```text
http://localhost:5188/account/login
```

The optional HTTPS profile uses ports `7188` and `5188`. The old ports `7080` and `5080` are no longer used.

If Visual Studio still remembers the previous `7080` profile:

1. Stop debugging and close Visual Studio.
2. Delete the hidden `.vs` folder beside the solution, plus all `bin` and `obj` folders.
3. Reopen `TahirFxTrader.sln`.
4. Select **TahirFxTrader.Web (HTTP)** from the run-profile dropdown.
5. Start the project again.

To inspect occupied development ports, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Check-DevelopmentPorts.ps1
```

## Startup error: A path base can only be configured using UsePathBase

Kestrel binding URLs must contain only the scheme, host, and port. Use:

```text
http://localhost:5188
```

The browser path belongs in `launchUrl` and may be `account/login`. It must not be appended to `applicationUrl` or `ASPNETCORE_URLS`.

Close Visual Studio and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Reset-LocalDevelopment.ps1
```

Then reopen the solution and select `TahirFxTrader.Web (HTTP)`. The application also sanitizes an accidentally path-based development URL before Kestrel starts.


## Automatic local SQL Server setup

If the application reports `Named Pipes Provider, error: 40`, the configured SQL Server instance is unavailable. From the solution directory, close Visual Studio and run PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Setup-LocalDatabase.ps1
```

The script detects LocalDB, SQL Server Express, or a default SQL Server instance, starts an installed service when possible, runs `Database/FXTraderDb.sql`, and writes the correct development connection string to `src/TahirFxTrader.Web/appsettings.Development.json`.

To specify an instance manually:

```powershell
.\scripts\Setup-LocalDatabase.ps1 -PreferredServer ".\SQLEXPRESS"
```


## Investment and profit wallet rules
- Approved deposits increase Investment Balance.
- Admin profit percentage is calculated only on the current available Investment Balance.
- Profit credits increase Profit Balance and total available balance.
- Withdrawals reserve Profit Balance first, then Investment Balance.
- Rejected withdrawals restore the exact original split.
- Run `Database/FXTraderDb.sql` again after updating an existing installation.


## Permanent User Trace ID

Every account receives an immutable unique ID in this format:

```text
USR-20260715-000001
```

The ID is generated during registration, displayed to the user after registration and on the dashboard/top bar, and appears in admin user, balance, deposit, and withdrawal screens. Admin users can search the Users page by this ID.

For an existing database, run:

```text
Database\UserTraceIdUpgrade.sql
```

Run `ProfitBalanceUpgrade.sql` first if the investment/profit balance upgrade has not yet been applied.

## Bulk profit allocation

Admin can open **Admin Panel → User Balances → Apply Profit % to All Users**. The percentage is calculated on each active user's available Investment Balance + Profit Balance. Existing profit is compounded; Commission Balance is excluded. The operation creates one `PFB-...` batch reference and one individual `PFT-...` reference and wallet-ledger entry per user.

For an existing database, run these upgrade scripts in order:

1. `Database/ProfitBalanceUpgrade.sql`
2. `Database/UserTraceIdUpgrade.sql`
3. `Database/BulkProfitUpgrade.sql`



## Repair: Invalid object name `dbo.UserTraceReferenceSeq`

This means the User Trace ID database upgrade was not fully applied. In SSMS, run:

```text
Database/RepairUserTraceSequence.sql
```

The script is safe to rerun. It backfills missing `USR-...` IDs, creates or advances the sequence, and recreates `sp_User_Register`.


## User Balances `Status` repair

If Admin > User Balances throws `IndexOutOfRangeException: Status`, run:

```text
Database\RepairUserBalanceStatus.sql
```

The script recreates both user-balance stored procedures with the required `Status` result column.


## Bulk profit `dbo.Users` repair

If bulk profit fails with `Invalid object name 'dbo.Users'`, run:

```text
Database\RepairBulkProfitDatabaseContext.sql
```

The project now schema-qualifies every stored-procedure call with `dbo.` so SQL Server does not resolve an accidental `sp_` procedure from `master`.


## Referral program upgrade

For an existing database, run `Database/ReferralProgramUpgrade.sql` after all earlier upgrade scripts.

- Registration links use `account/register?referral=USR-...`.
- A referral is qualified only when the referred user's first deposit is approved.
- Welcome bonus and referral commission percentages are configured separately in **Admin → Referrals**.
- Welcome bonus goes to Profit Balance. Referral commission goes to the separate Commission Balance. Both receive permanent wallet-ledger references.


## OLX Trade branding update

For an existing database, run `Database/OlxTradeBrandingUpgrade.sql` after the earlier feature upgrades. This updates existing payment-method account titles from the former visible brand to OLX Trade. The solution, namespaces, and database name intentionally remain unchanged to avoid breaking deployed installations.


## Compound profit and three-wallet model

Run `Database/CompoundProfitCommissionWalletUpgrade.sql` on an existing database. Profit is calculated on available Investment + Profit, while referral commission is stored separately. Withdrawals consume Profit, then Commission, then Investment. Existing historical profit balances are not automatically reclassified because older withdrawals did not record whether consumed profit came from admin profit or referral commission; all new referral commissions use the Commission Wallet.


## Dashboard social and mobile update
- Official WhatsApp, Facebook, Instagram, TikTok, Telegram, Threads, and Discord links are shown on the user dashboard.
- Sidebar support opens https://t.me/olxtradesupport.
- Mobile dashboard consolidates wallet and activity metrics into one compact overview card.
- Mobile Deposit and Withdraw actions are positioned on the right side of the portfolio hero.

## Wallet-source withdrawals

The withdrawal form now requires the user to choose one source:

- **Investment Wallet** — only the investment balance is used. The investment withdrawal fee is controlled in Admin → Settings. A per-user fee override can still be configured in Admin → Users.
- **Profit + Commission** — the combined profit and commission balance is available with 0% withdrawal fee. Profit is reserved first, then commission. Investment is never used for this option.

Existing databases must run `Database/WalletSourceWithdrawalUpgrade.sql` after the previous wallet/referral upgrades.

## Premium dashboard and referral link preview update

For an existing database, run:

```text
Database/DashboardReferralPreviewUpgrade.sql
```

This update:

- sets the referral commission to 5% (admin can change it later),
- adds the animated Inter-font user dashboard,
- changes personal referral links to `/invite/{USR-ID}` preview pages,
- adds Open Graph metadata for WhatsApp, Telegram, Facebook, and other link previews,
- shows a QR code that opens `/account/register?referral={USR-ID}` so the referral field is filled automatically.

Social preview crawlers cannot access `localhost`. Test the WhatsApp/Telegram image preview after publishing the site on a public HTTPS domain. The QR code is generated locally in the browser by `wwwroot/js/vendor/olx-qr.js`; no third-party QR API is required.


## Withdrawal Email OTP

Before a withdrawal is created, OLX Trade sends a six-digit verification code to the user's registered email. The code expires after two minutes and permits a maximum of five incorrect attempts. Run `Database/WithdrawalEmailOtpUpgrade.sql` once on an existing database.
