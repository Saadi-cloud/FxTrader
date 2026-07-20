# OLX Trade referral link preview

The user dashboard shares a public URL in this form:

`https://olxtrade.com/invite/USR-20260715-000001?preview=20260718-3`

The invite page exposes complete Open Graph and Twitter metadata and uses the optimized 1200 x 630 JPEG at:

`https://olxtrade.com/images/referral/olx-referral-og.jpg?v=20260718-3`

## Production settings

Set this in `src/TahirFxTrader.Web/appsettings.json`:

```json
"Site": {
  "PublicBaseUrl": "https://olxtrade.com",
  "ReferralPreviewVersion": "20260718-3"
}
```

The image and invite page must be public and accessible without authentication. WhatsApp does not render previews from localhost or private IP addresses.

## Refreshing a cached preview

Change `ReferralPreviewVersion` to a new value and redeploy. This changes both the shared link query and image query, which forces a fresh social scraper request.
