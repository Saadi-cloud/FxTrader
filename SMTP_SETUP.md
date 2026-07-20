# Gmail SMTP configuration

The project is configured for Gmail/Google Workspace SMTP using STARTTLS on port 587.

Configuration location:

`src/TahirFxTrader.Web/appsettings.json`

Important:

- The password must be a Google App Password, not the normal Google account password.
- Two-step verification must be enabled before generating an App Password.
- `admin@olxtrade.com` must be hosted in Google Workspace or configured as a permitted Gmail sender/alias.
- For production, prefer an environment variable or secret store instead of committing the SMTP password.

Environment variable example:

`Smtp__Password=YOUR_GOOGLE_APP_PASSWORD`
