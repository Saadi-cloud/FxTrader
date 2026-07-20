USE TahirFxTraderDb;
GO

/* OLX Trade visible-branding upgrade for existing databases. */
UPDATE dbo.PaymentMethods
SET AccountTitle = REPLACE(AccountTitle, N'FX Trader', N'OLX Trade'),
    UpdatedAtUtc = SYSUTCDATETIME()
WHERE AccountTitle LIKE N'%FX Trader%';
GO

UPDATE dbo.SystemSettings
SET UpdatedAtUtc = SYSUTCDATETIME()
WHERE Id = 1;
GO

PRINT 'Visible database branding updated to OLX Trade.';
GO
