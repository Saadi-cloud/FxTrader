/*
  OLX Trade - SQL Server database, tables, indexes, seed data, and stored procedures.
  Run in SQL Server Management Studio using an account allowed to create databases.
  Safe for a new installation. Existing rows are not deleted.
*/
USE master;
GO
IF DB_ID(N'TahirFxTraderDb') IS NULL
BEGIN
    CREATE DATABASE TahirFxTraderDb;
END
GO
USE TahirFxTraderDb;
GO

IF OBJECT_ID(N'dbo.Roles', N'U') IS NULL
CREATE TABLE dbo.Roles
(
    Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
    Name nvarchar(50) NOT NULL CONSTRAINT UQ_Roles_Name UNIQUE
);
GO
IF OBJECT_ID(N'dbo.Permissions', N'U') IS NULL
CREATE TABLE dbo.Permissions
(
    Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Permissions PRIMARY KEY,
    PermissionKey nvarchar(100) NOT NULL CONSTRAINT UQ_Permissions_Key UNIQUE,
    DisplayName nvarchar(150) NOT NULL
);
GO
IF OBJECT_ID(N'dbo.RolePermissions', N'U') IS NULL
CREATE TABLE dbo.RolePermissions
(
    RoleId int NOT NULL,
    PermissionId int NOT NULL,
    CONSTRAINT PK_RolePermissions PRIMARY KEY(RoleId, PermissionId),
    CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY(RoleId) REFERENCES dbo.Roles(Id),
    CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY(PermissionId) REFERENCES dbo.Permissions(Id)
);
GO
IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
CREATE TABLE dbo.Users
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    RoleId int NOT NULL,
    FullName nvarchar(120) NOT NULL,
    Email nvarchar(256) NOT NULL,
    PasswordHash nvarchar(500) NOT NULL,
    Status int NOT NULL CONSTRAINT DF_Users_Status DEFAULT(0),
    IsEmailVerified bit NOT NULL CONSTRAINT DF_Users_Verified DEFAULT(0),
    CanDeposit bit NOT NULL CONSTRAINT DF_Users_CanDeposit DEFAULT(1),
    CanWithdraw bit NOT NULL CONSTRAINT DF_Users_CanWithdraw DEFAULT(1),
    WithdrawalMinOverride decimal(19,4) NULL,
    WithdrawalMaxOverride decimal(19,4) NULL,
    WithdrawalFeePercentOverride decimal(9,4) NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_Users_Created DEFAULT(SYSUTCDATETIME()),
    UpdatedAtUtc datetime2(0) NULL,
    CONSTRAINT UQ_Users_Email UNIQUE(Email),
    CONSTRAINT FK_Users_Roles FOREIGN KEY(RoleId) REFERENCES dbo.Roles(Id),
    CONSTRAINT CK_Users_Status CHECK(Status IN (0,1,2,3)),
    CONSTRAINT CK_Users_WithdrawalFee CHECK(WithdrawalFeePercentOverride IS NULL OR WithdrawalFeePercentOverride >= 0 AND WithdrawalFeePercentOverride < 100)
);
GO
IF OBJECT_ID(N'dbo.UserWallets', N'U') IS NULL
CREATE TABLE dbo.UserWallets
(
    UserId bigint NOT NULL CONSTRAINT PK_UserWallets PRIMARY KEY,
    AvailableBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_Available DEFAULT(0),
    HeldBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_Held DEFAULT(0),
    UpdatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_Wallet_Updated DEFAULT(SYSUTCDATETIME()),
    RowVersion rowversion NOT NULL,
    CONSTRAINT FK_UserWallets_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Wallet_NonNegative CHECK(AvailableBalance >= 0 AND HeldBalance >= 0)
);
GO
IF OBJECT_ID(N'dbo.UserPermissionOverrides', N'U') IS NULL
CREATE TABLE dbo.UserPermissionOverrides
(
    UserId bigint NOT NULL,
    PermissionId int NOT NULL,
    IsAllowed bit NOT NULL,
    CONSTRAINT PK_UserPermissionOverrides PRIMARY KEY(UserId, PermissionId),
    CONSTRAINT FK_UserPermissionOverrides_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_UserPermissionOverrides_Permissions FOREIGN KEY(PermissionId) REFERENCES dbo.Permissions(Id)
);
GO
IF OBJECT_ID(N'dbo.EmailVerificationCodes', N'U') IS NULL
CREATE TABLE dbo.EmailVerificationCodes
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmailVerificationCodes PRIMARY KEY,
    UserId bigint NOT NULL,
    CodeHash char(64) NOT NULL,
    ExpiresAtUtc datetime2(0) NOT NULL,
    IsUsed bit NOT NULL CONSTRAINT DF_EmailCode_Used DEFAULT(0),
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_EmailCode_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_EmailCodes_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(Id)
);
GO
IF OBJECT_ID(N'dbo.PasswordResetCodes', N'U') IS NULL
CREATE TABLE dbo.PasswordResetCodes
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PasswordResetCodes PRIMARY KEY,
    UserId bigint NOT NULL,
    CodeHash char(64) NOT NULL,
    ExpiresAtUtc datetime2(0) NOT NULL,
    IsUsed bit NOT NULL CONSTRAINT DF_ResetCode_Used DEFAULT(0),
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ResetCode_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_ResetCodes_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(Id)
);
GO
IF OBJECT_ID(N'dbo.SystemSettings', N'U') IS NULL
CREATE TABLE dbo.SystemSettings
(
    Id tinyint NOT NULL,
    DefaultWithdrawalMin decimal(19,4) NOT NULL,
    DefaultWithdrawalMax decimal(19,4) NOT NULL,
    DefaultWithdrawalFeePercent decimal(9,4) NOT NULL,
    SupportEmail nvarchar(256) NOT NULL,
    TelegramUrl nvarchar(500) NOT NULL,
    UpdatedAtUtc datetime2(0) NOT NULL,
    UpdatedBy bigint NULL,
    CONSTRAINT PK_SystemSettings PRIMARY KEY(Id),
    CONSTRAINT CK_SystemSettings_Single CHECK(Id = 1)
);
GO
IF OBJECT_ID(N'dbo.PaymentMethods', N'U') IS NULL
CREATE TABLE dbo.PaymentMethods
(
    Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_PaymentMethods PRIMARY KEY,
    Name nvarchar(100) NOT NULL,
    Code nvarchar(50) NOT NULL CONSTRAINT UQ_PaymentMethods_Code UNIQUE,
    MethodType int NOT NULL,
    AccountTitle nvarchar(150) NULL,
    AccountNumber nvarchar(250) NULL,
    BankName nvarchar(150) NULL,
    WalletAddress nvarchar(500) NULL,
    Network nvarchar(100) NULL,
    QrImagePath nvarchar(500) NULL,
    Instructions nvarchar(1000) NULL,
    MinDeposit decimal(19,4) NOT NULL CONSTRAINT DF_PM_MinDeposit DEFAULT(0),
    MaxDeposit decimal(19,4) NULL,
    MinWithdrawal decimal(19,4) NOT NULL CONSTRAINT DF_PM_MinWithdrawal DEFAULT(0),
    MaxWithdrawal decimal(19,4) NULL,
    DepositFeePercent decimal(9,4) NOT NULL CONSTRAINT DF_PM_DepositFee DEFAULT(0),
    WithdrawalFeePercent decimal(9,4) NOT NULL CONSTRAINT DF_PM_WithdrawalFee DEFAULT(0),
    SupportsDeposit bit NOT NULL CONSTRAINT DF_PM_Deposit DEFAULT(1),
    SupportsWithdrawal bit NOT NULL CONSTRAINT DF_PM_Withdrawal DEFAULT(1),
    IsActive bit NOT NULL CONSTRAINT DF_PM_Active DEFAULT(1),
    DisplayOrder int NOT NULL CONSTRAINT DF_PM_Order DEFAULT(0),
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_PM_Created DEFAULT(SYSUTCDATETIME()),
    UpdatedAtUtc datetime2(0) NULL,
    CONSTRAINT CK_PM_Type CHECK(MethodType IN (1,2,3,4,5)),
    CONSTRAINT CK_PM_DepositFee CHECK(DepositFeePercent >= 0 AND DepositFeePercent < 100),
    CONSTRAINT CK_PM_WithdrawalFee CHECK(WithdrawalFeePercent >= 0 AND WithdrawalFeePercent < 100)
);
GO
IF OBJECT_ID(N'dbo.DepositReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.DepositReferenceSeq AS bigint START WITH 1 INCREMENT BY 1;
GO
IF OBJECT_ID(N'dbo.WithdrawalReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.WithdrawalReferenceSeq AS bigint START WITH 1 INCREMENT BY 1;
GO
IF OBJECT_ID(N'dbo.Deposits', N'U') IS NULL
CREATE TABLE dbo.Deposits
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Deposits PRIMARY KEY,
    ReferenceNo nvarchar(40) NOT NULL CONSTRAINT UQ_Deposits_Reference UNIQUE,
    UserId bigint NOT NULL,
    PaymentMethodId int NOT NULL,
    Amount decimal(19,4) NOT NULL,
    FeeAmount decimal(19,4) NOT NULL,
    NetAmount decimal(19,4) NOT NULL,
    SenderAccount nvarchar(200) NOT NULL,
    TransactionReference nvarchar(150) NOT NULL,
    ScreenshotPath nvarchar(500) NOT NULL,
    Status int NOT NULL CONSTRAINT DF_Deposits_Status DEFAULT(0),
    AdminNote nvarchar(500) NULL,
    ReviewedBy bigint NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_Deposits_Created DEFAULT(SYSUTCDATETIME()),
    ReviewedAtUtc datetime2(0) NULL,
    CONSTRAINT FK_Deposits_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Deposits_Methods FOREIGN KEY(PaymentMethodId) REFERENCES dbo.PaymentMethods(Id),
    CONSTRAINT FK_Deposits_Reviewer FOREIGN KEY(ReviewedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Deposits_Status CHECK(Status IN (0,2,4)),
    CONSTRAINT CK_Deposits_Amount CHECK(Amount > 0 AND FeeAmount >= 0 AND NetAmount >= 0)
);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='UX_Deposits_MethodTransactionRef' AND object_id=OBJECT_ID('dbo.Deposits'))
CREATE UNIQUE INDEX UX_Deposits_MethodTransactionRef ON dbo.Deposits(PaymentMethodId, TransactionReference);
GO
IF OBJECT_ID(N'dbo.Withdrawals', N'U') IS NULL
CREATE TABLE dbo.Withdrawals
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Withdrawals PRIMARY KEY,
    ReferenceNo nvarchar(40) NOT NULL CONSTRAINT UQ_Withdrawals_Reference UNIQUE,
    UserId bigint NOT NULL,
    PaymentMethodId int NOT NULL,
    Amount decimal(19,4) NOT NULL,
    FeePercent decimal(9,4) NOT NULL,
    FeeAmount decimal(19,4) NOT NULL,
    NetAmount decimal(19,4) NOT NULL,
    DestinationJson nvarchar(max) NOT NULL,
    DestinationDisplay nvarchar(300) NOT NULL,
    Status int NOT NULL CONSTRAINT DF_Withdrawals_Status DEFAULT(0),
    AdminNote nvarchar(500) NULL,
    AdminPaymentReference nvarchar(150) NULL,
    ReviewedBy bigint NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_Withdrawals_Created DEFAULT(SYSUTCDATETIME()),
    ProcessingAtUtc datetime2(0) NULL,
    CompletedAtUtc datetime2(0) NULL,
    CONSTRAINT FK_Withdrawals_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Withdrawals_Methods FOREIGN KEY(PaymentMethodId) REFERENCES dbo.PaymentMethods(Id),
    CONSTRAINT FK_Withdrawals_Reviewer FOREIGN KEY(ReviewedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Withdrawals_Status CHECK(Status IN (0,1,3,4)),
    CONSTRAINT CK_Withdrawals_Amount CHECK(Amount > 0 AND FeeAmount >= 0 AND NetAmount >= 0),
    CONSTRAINT CK_Withdrawals_Json CHECK(ISJSON(DestinationJson)=1)
);
GO
IF OBJECT_ID(N'dbo.WalletLedger', N'U') IS NULL
CREATE TABLE dbo.WalletLedger
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_WalletLedger PRIMARY KEY,
    UserId bigint NOT NULL,
    EntryType nvarchar(40) NOT NULL,
    ReferenceNo nvarchar(40) NOT NULL,
    Description nvarchar(250) NOT NULL,
    Credit decimal(19,4) NOT NULL CONSTRAINT DF_Ledger_Credit DEFAULT(0),
    Debit decimal(19,4) NOT NULL CONSTRAINT DF_Ledger_Debit DEFAULT(0),
    BalanceAfter decimal(19,4) NOT NULL,
    RelatedEntityType nvarchar(30) NOT NULL,
    RelatedEntityId bigint NOT NULL,
    IsVisible bit NOT NULL CONSTRAINT DF_Ledger_Visible DEFAULT(1),
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_Ledger_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_WalletLedger_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Ledger_OneSide CHECK((Credit > 0 AND Debit = 0) OR (Debit > 0 AND Credit = 0))
);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='UX_Ledger_Related' AND object_id=OBJECT_ID('dbo.WalletLedger'))
CREATE UNIQUE INDEX UX_Ledger_Related ON dbo.WalletLedger(RelatedEntityType, RelatedEntityId);
GO
IF OBJECT_ID(N'dbo.AuditLogs', N'U') IS NULL
CREATE TABLE dbo.AuditLogs
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditLogs PRIMARY KEY,
    UserId bigint NULL,
    ActionName nvarchar(100) NOT NULL,
    EntityType nvarchar(60) NOT NULL,
    EntityId nvarchar(60) NULL,
    Details nvarchar(max) NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_Audit_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_AuditLogs_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(Id)
);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Deposits_User_Created' AND object_id=OBJECT_ID('dbo.Deposits')) CREATE INDEX IX_Deposits_User_Created ON dbo.Deposits(UserId, CreatedAtUtc DESC);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Withdrawals_User_Created' AND object_id=OBJECT_ID('dbo.Withdrawals')) CREATE INDEX IX_Withdrawals_User_Created ON dbo.Withdrawals(UserId, CreatedAtUtc DESC);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Ledger_User_Created' AND object_id=OBJECT_ID('dbo.WalletLedger')) CREATE INDEX IX_Ledger_User_Created ON dbo.WalletLedger(UserId, CreatedAtUtc DESC);
GO

/* Seed security and settings */
IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE Name=N'Admin') INSERT dbo.Roles(Name) VALUES(N'Admin');
IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE Name=N'User') INSERT dbo.Roles(Name) VALUES(N'User');
GO
MERGE dbo.Permissions AS t USING (VALUES
(N'Deposit.Create',N'Create deposits'),(N'Deposit.History',N'View deposit history'),(N'Withdrawal.Create',N'Create withdrawals'),(N'Withdrawal.History',N'View withdrawal history'),(N'Statement.View',N'View account statement')
) AS s(PermissionKey,DisplayName) ON t.PermissionKey=s.PermissionKey
WHEN NOT MATCHED THEN INSERT(PermissionKey,DisplayName) VALUES(s.PermissionKey,s.DisplayName);
GO
INSERT dbo.RolePermissions(RoleId,PermissionId)
SELECT r.Id,p.Id FROM dbo.Roles r CROSS JOIN dbo.Permissions p
WHERE r.Name IN(N'Admin',N'User') AND NOT EXISTS(SELECT 1 FROM dbo.RolePermissions rp WHERE rp.RoleId=r.Id AND rp.PermissionId=p.Id);
GO
IF NOT EXISTS(SELECT 1 FROM dbo.SystemSettings WHERE Id=1)
INSERT dbo.SystemSettings(Id,DefaultWithdrawalMin,DefaultWithdrawalMax,DefaultWithdrawalFeePercent,SupportEmail,TelegramUrl,UpdatedAtUtc)
VALUES(1,50,50000,1.5,N'support@example.com',N'https://t.me/yourchannel',SYSUTCDATETIME());
GO
DECLARE @AdminRoleId int=(SELECT Id FROM dbo.Roles WHERE Name=N'Admin');
IF NOT EXISTS(SELECT 1 FROM dbo.Users WHERE Email=N'admin@fxtrader.local')
BEGIN
    INSERT dbo.Users(RoleId,FullName,Email,PasswordHash,Status,IsEmailVerified,CanDeposit,CanWithdraw)
    VALUES(@AdminRoleId,N'System Administrator',N'admin@fxtrader.local',N'PBKDF2$120000$8V9pNfAkvJvifKvhv1wpYA==$Tmzase8lVDtgnAeQ/OdRm7gbIBTliSvHBaUi7lLOw44=',1,1,1,1);
    INSERT dbo.UserWallets(UserId) VALUES(SCOPE_IDENTITY());
END
GO
MERGE dbo.PaymentMethods AS t USING (VALUES
(N'JazzCash',N'JAZZCASH',2,N'OLX Trade Payments',N'0300-0000000',NULL,NULL,NULL,N'Send payment to this JazzCash number, then upload a clear screenshot.',20,NULL,50,10000,0,1.5,1,1,1,1),
(N'EasyPaisa',N'EASYPAISA',3,N'OLX Trade Payments',N'0310-0000000',NULL,NULL,NULL,N'Send payment to this EasyPaisa number, then upload a clear screenshot.',20,NULL,50,10000,0,1.5,1,1,1,2),
(N'Bank Transfer',N'BANK',1,N'OLX Trade Payments',N'PK00 BANK 0000 0000 0000 0000',N'Your Bank Name',NULL,NULL,N'Use your transaction or trail ID when submitting the deposit.',50,NULL,100,50000,0,1,1,1,1,3),
(N'USDT TRC20',N'USDT_TRC20',4,N'OLX Trade Wallet',NULL,NULL,N'TXXXXXXXXXXXXXXXXXXXXXXXXXXXX',N'USDT TRC20',N'Only send USDT on the TRC20 network.',20,NULL,20,50000,0,1,1,1,1,4)
) AS s(Name,Code,MethodType,AccountTitle,AccountNumber,BankName,WalletAddress,Network,Instructions,MinDeposit,MaxDeposit,MinWithdrawal,MaxWithdrawal,DepositFeePercent,WithdrawalFeePercent,SupportsDeposit,SupportsWithdrawal,IsActive,DisplayOrder)
ON t.Code=s.Code
WHEN NOT MATCHED THEN INSERT(Name,Code,MethodType,AccountTitle,AccountNumber,BankName,WalletAddress,Network,Instructions,MinDeposit,MaxDeposit,MinWithdrawal,MaxWithdrawal,DepositFeePercent,WithdrawalFeePercent,SupportsDeposit,SupportsWithdrawal,IsActive,DisplayOrder)
VALUES(s.Name,s.Code,s.MethodType,s.AccountTitle,s.AccountNumber,s.BankName,s.WalletAddress,s.Network,s.Instructions,s.MinDeposit,s.MaxDeposit,s.MinWithdrawal,s.MaxWithdrawal,s.DepositFeePercent,s.WithdrawalFeePercent,s.SupportsDeposit,s.SupportsWithdrawal,s.IsActive,s.DisplayOrder);
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetByEmail @Email nvarchar(256)
AS
BEGIN SET NOCOUNT ON;
SELECT u.Id,u.FullName,u.Email,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
       ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,u.CreatedAtUtc
FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Email=LOWER(LTRIM(RTRIM(@Email)));
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_GetById @UserId bigint
AS
BEGIN SET NOCOUNT ON;
SELECT u.Id,u.FullName,u.Email,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
       ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,u.CreatedAtUtc
FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Id=@UserId;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_Register @FullName nvarchar(120),@Email nvarchar(256),@PasswordHash nvarchar(500)
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
SET @Email=LOWER(LTRIM(RTRIM(@Email)));
IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email) BEGIN SELECT CAST(0 AS bit) Succeeded,N'An account already exists with this email address.' Message,CAST(NULL AS bigint) Id; RETURN; END
BEGIN TRY BEGIN TRAN;
DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=N'User');
INSERT dbo.Users(RoleId,FullName,Email,PasswordHash,Status,IsEmailVerified,CanDeposit,CanWithdraw) VALUES(@RoleId,LTRIM(RTRIM(@FullName)),@Email,@PasswordHash,0,0,1,1);
DECLARE @Id bigint=SCOPE_IDENTITY(); INSERT dbo.UserWallets(UserId) VALUES(@Id);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Account created.' Message,@Id Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id; END CATCH
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_EmailCode_Save @UserId bigint,@CodeHash char(64),@ExpiresAtUtc datetime2(0)
AS BEGIN SET NOCOUNT ON; UPDATE dbo.EmailVerificationCodes SET IsUsed=1 WHERE UserId=@UserId AND IsUsed=0; INSERT dbo.EmailVerificationCodes(UserId,CodeHash,ExpiresAtUtc) VALUES(@UserId,@CodeHash,@ExpiresAtUtc); END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_EmailCode_Get @UserId bigint
AS BEGIN SET NOCOUNT ON; SELECT TOP(1) CodeHash,ExpiresAtUtc,IsUsed FROM dbo.EmailVerificationCodes WHERE UserId=@UserId ORDER BY Id DESC; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_Email_Verify @UserId bigint
AS BEGIN SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRAN; UPDATE dbo.EmailVerificationCodes SET IsUsed=1 WHERE UserId=@UserId AND IsUsed=0; UPDATE dbo.Users SET IsEmailVerified=1,Status=CASE WHEN Status=0 THEN 1 ELSE Status END,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=@UserId; COMMIT; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_ResetCode_Save @UserId bigint,@CodeHash char(64),@ExpiresAtUtc datetime2(0)
AS BEGIN SET NOCOUNT ON; UPDATE dbo.PasswordResetCodes SET IsUsed=1 WHERE UserId=@UserId AND IsUsed=0; INSERT dbo.PasswordResetCodes(UserId,CodeHash,ExpiresAtUtc) VALUES(@UserId,@CodeHash,@ExpiresAtUtc); END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_ResetCode_Get @UserId bigint
AS BEGIN SET NOCOUNT ON; SELECT TOP(1) CodeHash,ExpiresAtUtc,IsUsed FROM dbo.PasswordResetCodes WHERE UserId=@UserId ORDER BY Id DESC; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_Password_Update @UserId bigint,@PasswordHash nvarchar(500)
AS BEGIN SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRAN; UPDATE dbo.Users SET PasswordHash=@PasswordHash,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=@UserId; UPDATE dbo.PasswordResetCodes SET IsUsed=1 WHERE UserId=@UserId AND IsUsed=0; COMMIT; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_Permissions_GetEffective @UserId bigint
AS
BEGIN SET NOCOUNT ON;
SELECT p.PermissionKey FROM dbo.Users u JOIN dbo.RolePermissions rp ON rp.RoleId=u.RoleId JOIN dbo.Permissions p ON p.Id=rp.PermissionId
LEFT JOIN dbo.UserPermissionOverrides o ON o.UserId=u.Id AND o.PermissionId=p.Id
WHERE u.Id=@UserId AND ISNULL(o.IsAllowed,1)=1 ORDER BY p.PermissionKey;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Users_GetAll
AS BEGIN SET NOCOUNT ON;
SELECT u.Id,u.FullName,u.Email,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,ISNULL(w.AvailableBalance,0) AvailableBalance,u.CreatedAtUtc
FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id ORDER BY u.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_Get @UserId bigint
AS
BEGIN SET NOCOUNT ON;
SELECT u.Id,u.FullName,u.Email,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride
FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId WHERE u.Id=@UserId;
SELECT p.PermissionKey,CAST(ISNULL(o.IsAllowed,CASE WHEN rp.PermissionId IS NULL THEN 0 ELSE 1 END) AS bit) IsAllowed
FROM dbo.Permissions p CROSS JOIN dbo.Users u LEFT JOIN dbo.RolePermissions rp ON rp.RoleId=u.RoleId AND rp.PermissionId=p.Id
LEFT JOIN dbo.UserPermissionOverrides o ON o.UserId=u.Id AND o.PermissionId=p.Id WHERE u.Id=@UserId ORDER BY p.PermissionKey;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_Update
@UserId bigint,@FullName nvarchar(120),@Email nvarchar(256),@RoleName nvarchar(50),@Status int,@IsEmailVerified bit,@CanDeposit bit,@CanWithdraw bit,
@WithdrawalMinOverride decimal(19,4)=NULL,@WithdrawalMaxOverride decimal(19,4)=NULL,@WithdrawalFeePercentOverride decimal(9,4)=NULL,@PermissionsJson nvarchar(max),@AdminId bigint
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
SET @Email=LOWER(LTRIM(RTRIM(@Email)));
IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email AND Id<>@UserId) BEGIN SELECT CAST(0 AS bit) Succeeded,N'Email address is already assigned to another user.' Message,CAST(@UserId AS bigint) Id; RETURN; END
DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=@RoleName); IF @RoleId IS NULL BEGIN SELECT CAST(0 AS bit) Succeeded,N'Invalid role.' Message,CAST(@UserId AS bigint) Id; RETURN; END
IF @WithdrawalMinOverride IS NOT NULL AND @WithdrawalMaxOverride IS NOT NULL AND @WithdrawalMinOverride>@WithdrawalMaxOverride BEGIN SELECT CAST(0 AS bit) Succeeded,N'Minimum withdrawal cannot exceed maximum withdrawal.' Message,CAST(@UserId AS bigint) Id; RETURN; END
BEGIN TRY BEGIN TRAN;
UPDATE dbo.Users SET FullName=@FullName,Email=@Email,RoleId=@RoleId,Status=@Status,IsEmailVerified=@IsEmailVerified,CanDeposit=@CanDeposit,CanWithdraw=@CanWithdraw,
WithdrawalMinOverride=@WithdrawalMinOverride,WithdrawalMaxOverride=@WithdrawalMaxOverride,WithdrawalFeePercentOverride=@WithdrawalFeePercentOverride,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=@UserId;
DELETE FROM dbo.UserPermissionOverrides WHERE UserId=@UserId;
INSERT dbo.UserPermissionOverrides(UserId,PermissionId,IsAllowed)
SELECT @UserId,p.Id,CAST(CASE WHEN s.PermissionKey IS NULL THEN 0 ELSE 1 END AS bit)
FROM dbo.Permissions p LEFT JOIN OPENJSON(@PermissionsJson) WITH(PermissionKey nvarchar(100) '$') s ON s.PermissionKey=p.PermissionKey;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'User.Update',N'User',CONVERT(nvarchar(60),@UserId),@PermissionsJson);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'User controls updated.' Message,@UserId Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@UserId Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_PaymentMethods_GetActiveDeposit
AS BEGIN SET NOCOUNT ON; SELECT Id,Name,Code,MethodType,AccountTitle,AccountNumber,BankName,WalletAddress,Network,QrImagePath,Instructions,MinDeposit,MaxDeposit,MinWithdrawal,MaxWithdrawal,DepositFeePercent,WithdrawalFeePercent,SupportsDeposit,SupportsWithdrawal,IsActive,DisplayOrder FROM dbo.PaymentMethods WHERE IsActive=1 AND SupportsDeposit=1 ORDER BY DisplayOrder,Name; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_PaymentMethods_GetActiveWithdrawal
AS BEGIN SET NOCOUNT ON; SELECT Id,Name,Code,MethodType,AccountTitle,AccountNumber,BankName,WalletAddress,Network,QrImagePath,Instructions,MinDeposit,MaxDeposit,MinWithdrawal,MaxWithdrawal,DepositFeePercent,WithdrawalFeePercent,SupportsDeposit,SupportsWithdrawal,IsActive,DisplayOrder FROM dbo.PaymentMethods WHERE IsActive=1 AND SupportsWithdrawal=1 ORDER BY DisplayOrder,Name; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_PaymentMethods_GetAll
AS BEGIN SET NOCOUNT ON; SELECT Id,Name,Code,MethodType,AccountTitle,AccountNumber,BankName,WalletAddress,Network,QrImagePath,Instructions,MinDeposit,MaxDeposit,MinWithdrawal,MaxWithdrawal,DepositFeePercent,WithdrawalFeePercent,SupportsDeposit,SupportsWithdrawal,IsActive,DisplayOrder FROM dbo.PaymentMethods ORDER BY DisplayOrder,Name; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_PaymentMethod_GetById @Id int
AS BEGIN SET NOCOUNT ON; SELECT Id,Name,Code,MethodType,AccountTitle,AccountNumber,BankName,WalletAddress,Network,QrImagePath,Instructions,MinDeposit,MaxDeposit,MinWithdrawal,MaxWithdrawal,DepositFeePercent,WithdrawalFeePercent,SupportsDeposit,SupportsWithdrawal,IsActive,DisplayOrder FROM dbo.PaymentMethods WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_PaymentMethod_Create
@Name nvarchar(100),@Code nvarchar(50),@MethodType int,@AccountTitle nvarchar(150)=NULL,@AccountNumber nvarchar(250)=NULL,@BankName nvarchar(150)=NULL,@WalletAddress nvarchar(500)=NULL,@Network nvarchar(100)=NULL,@QrImagePath nvarchar(500)=NULL,@Instructions nvarchar(1000)=NULL,
@MinDeposit decimal(19,4),@MaxDeposit decimal(19,4)=NULL,@MinWithdrawal decimal(19,4),@MaxWithdrawal decimal(19,4)=NULL,@DepositFeePercent decimal(9,4),@WithdrawalFeePercent decimal(9,4),@SupportsDeposit bit,@SupportsWithdrawal bit,@IsActive bit,@DisplayOrder int,@AdminId bigint
AS
BEGIN SET NOCOUNT ON;
IF EXISTS(SELECT 1 FROM dbo.PaymentMethods WHERE Code=@Code) BEGIN SELECT CAST(0 AS bit) Succeeded,N'Payment method code already exists.' Message,CAST(NULL AS bigint) Id; RETURN; END
INSERT dbo.PaymentMethods(Name,Code,MethodType,AccountTitle,AccountNumber,BankName,WalletAddress,Network,QrImagePath,Instructions,MinDeposit,MaxDeposit,MinWithdrawal,MaxWithdrawal,DepositFeePercent,WithdrawalFeePercent,SupportsDeposit,SupportsWithdrawal,IsActive,DisplayOrder)
VALUES(@Name,@Code,@MethodType,@AccountTitle,@AccountNumber,@BankName,@WalletAddress,@Network,@QrImagePath,@Instructions,@MinDeposit,@MaxDeposit,@MinWithdrawal,@MaxWithdrawal,@DepositFeePercent,@WithdrawalFeePercent,@SupportsDeposit,@SupportsWithdrawal,@IsActive,@DisplayOrder);
DECLARE @Id bigint=SCOPE_IDENTITY(); INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId) VALUES(@AdminId,N'PaymentMethod.Create',N'PaymentMethod',CONVERT(nvarchar(60),@Id)); SELECT CAST(1 AS bit) Succeeded,N'Payment method created.' Message,@Id Id;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_PaymentMethod_Update
@Id int,@Name nvarchar(100),@Code nvarchar(50),@MethodType int,@AccountTitle nvarchar(150)=NULL,@AccountNumber nvarchar(250)=NULL,@BankName nvarchar(150)=NULL,@WalletAddress nvarchar(500)=NULL,@Network nvarchar(100)=NULL,@QrImagePath nvarchar(500)=NULL,@Instructions nvarchar(1000)=NULL,
@MinDeposit decimal(19,4),@MaxDeposit decimal(19,4)=NULL,@MinWithdrawal decimal(19,4),@MaxWithdrawal decimal(19,4)=NULL,@DepositFeePercent decimal(9,4),@WithdrawalFeePercent decimal(9,4),@SupportsDeposit bit,@SupportsWithdrawal bit,@IsActive bit,@DisplayOrder int,@AdminId bigint
AS
BEGIN SET NOCOUNT ON;
IF EXISTS(SELECT 1 FROM dbo.PaymentMethods WHERE Code=@Code AND Id<>@Id) BEGIN SELECT CAST(0 AS bit) Succeeded,N'Payment method code already exists.' Message,CAST(@Id AS bigint) Id; RETURN; END
UPDATE dbo.PaymentMethods SET Name=@Name,Code=@Code,MethodType=@MethodType,AccountTitle=@AccountTitle,AccountNumber=@AccountNumber,BankName=@BankName,WalletAddress=@WalletAddress,Network=@Network,QrImagePath=@QrImagePath,Instructions=@Instructions,MinDeposit=@MinDeposit,MaxDeposit=@MaxDeposit,MinWithdrawal=@MinWithdrawal,MaxWithdrawal=@MaxWithdrawal,DepositFeePercent=@DepositFeePercent,WithdrawalFeePercent=@WithdrawalFeePercent,SupportsDeposit=@SupportsDeposit,SupportsWithdrawal=@SupportsWithdrawal,IsActive=@IsActive,DisplayOrder=@DisplayOrder,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId) VALUES(@AdminId,N'PaymentMethod.Update',N'PaymentMethod',CONVERT(nvarchar(60),@Id)); SELECT CAST(1 AS bit) Succeeded,N'Payment method updated.' Message,CAST(@Id AS bigint) Id;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_PaymentMethod_Delete @Id int,@AdminId bigint
AS BEGIN SET NOCOUNT ON; UPDATE dbo.PaymentMethods SET IsActive=0,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=@Id; INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId) VALUES(@AdminId,N'PaymentMethod.Disable',N'PaymentMethod',CONVERT(nvarchar(60),@Id)); SELECT CAST(1 AS bit) Succeeded,N'Payment method disabled.' Message,CAST(@Id AS bigint) Id; END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Deposit_Create @UserId bigint,@PaymentMethodId int,@Amount decimal(19,4),@TransactionReference nvarchar(150),@SenderAccount nvarchar(200),@ScreenshotPath nvarchar(500)
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @CanDeposit bit,@Status int,@IsVerified bit,@Min decimal(19,4),@Max decimal(19,4),@FeePct decimal(9,4),@Active bit,@Supports bit;
SELECT @CanDeposit=CanDeposit,@Status=Status,@IsVerified=IsEmailVerified FROM dbo.Users WHERE Id=@UserId;
SELECT @Min=MinDeposit,@Max=MaxDeposit,@FeePct=DepositFeePercent,@Active=IsActive,@Supports=SupportsDeposit FROM dbo.PaymentMethods WHERE Id=@PaymentMethodId;
IF ISNULL(@Status,-1)<>1 OR ISNULL(@IsVerified,0)<>1 OR ISNULL(@CanDeposit,0)<>1 BEGIN SELECT CAST(0 AS bit) Succeeded,N'Deposits are not allowed for this account.' Message,CAST(NULL AS bigint) Id; RETURN; END
IF ISNULL(@Active,0)<>1 OR ISNULL(@Supports,0)<>1 BEGIN SELECT CAST(0 AS bit) Succeeded,N'The selected deposit method is unavailable.' Message,CAST(NULL AS bigint) Id; RETURN; END
IF @Amount<@Min OR (@Max IS NOT NULL AND @Amount>@Max) BEGIN SELECT CAST(0 AS bit) Succeeded,N'Deposit amount is outside the allowed limits.' Message,CAST(NULL AS bigint) Id; RETURN; END
IF EXISTS(SELECT 1 FROM dbo.Deposits WHERE PaymentMethodId=@PaymentMethodId AND TransactionReference=LTRIM(RTRIM(@TransactionReference))) BEGIN SELECT CAST(0 AS bit) Succeeded,N'This transaction reference has already been submitted.' Message,CAST(NULL AS bigint) Id; RETURN; END
DECLARE @Fee decimal(19,4)=ROUND(@Amount*@FeePct/100.0,4),@Net decimal(19,4)=@Amount-ROUND(@Amount*@FeePct/100.0,4),@Seq bigint=NEXT VALUE FOR dbo.DepositReferenceSeq,@Ref nvarchar(40);
SET @Ref=N'DPT-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);
INSERT dbo.Deposits(ReferenceNo,UserId,PaymentMethodId,Amount,FeeAmount,NetAmount,SenderAccount,TransactionReference,ScreenshotPath,Status)
VALUES(@Ref,@UserId,@PaymentMethodId,@Amount,@Fee,@Net,LTRIM(RTRIM(@SenderAccount)),LTRIM(RTRIM(@TransactionReference)),@ScreenshotPath,0);
DECLARE @Id bigint=SCOPE_IDENTITY(); SELECT CAST(1 AS bit) Succeeded,N'Deposit request submitted for administrator review.' Message,@Id Id;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Deposits_GetByUser @UserId bigint
AS BEGIN SET NOCOUNT ON;
SELECT d.Id,d.ReferenceNo,d.UserId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
FROM dbo.Deposits d JOIN dbo.Users u ON u.Id=d.UserId JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId WHERE d.UserId=@UserId ORDER BY d.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposits_GetAll
AS BEGIN SET NOCOUNT ON;
SELECT d.Id,d.ReferenceNo,d.UserId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
FROM dbo.Deposits d JOIN dbo.Users u ON u.Id=d.UserId JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId ORDER BY CASE WHEN d.Status=0 THEN 0 ELSE 1 END,d.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_GetById @Id bigint
AS BEGIN SET NOCOUNT ON;
SELECT d.Id,d.ReferenceNo,d.UserId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
FROM dbo.Deposits d JOIN dbo.Users u ON u.Id=d.UserId JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId WHERE d.Id=@Id;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Approve @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
BEGIN TRY BEGIN TRAN;
DECLARE @Status int,@UserId bigint,@Net decimal(19,4),@Ref nvarchar(40),@Balance decimal(19,4);
SELECT @Status=Status,@UserId=UserId,@Net=NetAmount,@Ref=ReferenceNo FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id; RETURN; END
IF @Status<>0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id; RETURN; END
UPDATE dbo.UserWallets SET AvailableBalance=AvailableBalance+@Net,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId; SELECT @Balance=AvailableBalance FROM dbo.UserWallets WHERE UserId=@UserId;
UPDATE dbo.Deposits SET Status=2,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
VALUES(@UserId,N'DepositCredit',@Ref,N'Approved deposit',@Net,0,@Balance,N'Deposit',@Id,1);
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Deposit.Approve',N'Deposit',CONVERT(nvarchar(60),@Id),@AdminNote);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Deposit approved and user wallet credited.' Message,@Id Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Reject @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
BEGIN TRAN; DECLARE @Status int=(SELECT Status FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id);
IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id; RETURN; END
IF @Status<>0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id; RETURN; END
UPDATE dbo.Deposits SET Status=4,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Deposit.Reject',N'Deposit',CONVERT(nvarchar(60),@Id),@AdminNote);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Deposit rejected.' Message,@Id Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawal_Create @UserId bigint,@PaymentMethodId int,@Amount decimal(19,4),@DestinationJson nvarchar(max),@DestinationDisplay nvarchar(300)
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
IF ISJSON(@DestinationJson)<>1 BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal destination is invalid.' Message,CAST(NULL AS bigint) Id; RETURN; END
BEGIN TRY BEGIN TRAN;
DECLARE @Can bit,@UserStatus int,@Verified bit,@UserMin decimal(19,4),@UserMax decimal(19,4),@UserFee decimal(9,4),@Available decimal(19,4),@GlobalMin decimal(19,4),@GlobalMax decimal(19,4),@GlobalFee decimal(9,4),
@MethodMin decimal(19,4),@MethodMax decimal(19,4),@MethodFee decimal(9,4),@MethodActive bit,@Supports bit,@EffectiveMin decimal(19,4),@EffectiveMax decimal(19,4),@FeePct decimal(9,4);
SELECT @Can=u.CanWithdraw,@UserStatus=u.Status,@Verified=u.IsEmailVerified,@UserMin=u.WithdrawalMinOverride,@UserMax=u.WithdrawalMaxOverride,@UserFee=u.WithdrawalFeePercentOverride,@Available=w.AvailableBalance
FROM dbo.Users u JOIN dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id WHERE u.Id=@UserId;
SELECT @GlobalMin=DefaultWithdrawalMin,@GlobalMax=DefaultWithdrawalMax,@GlobalFee=DefaultWithdrawalFeePercent FROM dbo.SystemSettings WHERE Id=1;
SELECT @MethodMin=MinWithdrawal,@MethodMax=MaxWithdrawal,@MethodFee=WithdrawalFeePercent,@MethodActive=IsActive,@Supports=SupportsWithdrawal FROM dbo.PaymentMethods WHERE Id=@PaymentMethodId;
IF ISNULL(@UserStatus,-1)<>1 OR ISNULL(@Verified,0)<>1 OR ISNULL(@Can,0)<>1 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawals are disabled for this account.' Message,CAST(NULL AS bigint) Id; RETURN; END
IF ISNULL(@MethodActive,0)<>1 OR ISNULL(@Supports,0)<>1 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'The selected withdrawal method is unavailable.' Message,CAST(NULL AS bigint) Id; RETURN; END
SET @EffectiveMin=CASE WHEN ISNULL(@UserMin,@GlobalMin)>@MethodMin THEN ISNULL(@UserMin,@GlobalMin) ELSE @MethodMin END;
SET @EffectiveMax=ISNULL(@UserMax,@GlobalMax); IF @MethodMax IS NOT NULL AND @MethodMax<@EffectiveMax SET @EffectiveMax=@MethodMax;
SET @FeePct=COALESCE(@UserFee,NULLIF(@MethodFee,0),@GlobalFee);
IF @Amount<@EffectiveMin OR @Amount>@EffectiveMax BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,CAST(NULL AS bigint) Id; RETURN; END
IF @Available<@Amount BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Insufficient available balance.' Message,CAST(NULL AS bigint) Id; RETURN; END
DECLARE @Fee decimal(19,4)=ROUND(@Amount*@FeePct/100.0,4),@Net decimal(19,4)=@Amount-ROUND(@Amount*@FeePct/100.0,4),@Seq bigint=NEXT VALUE FOR dbo.WithdrawalReferenceSeq,@Ref nvarchar(40),@Balance decimal(19,4);
IF @Net<=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount must be greater than the fee.' Message,CAST(NULL AS bigint) Id; RETURN; END
SET @Ref=N'WDL-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);
UPDATE dbo.UserWallets SET AvailableBalance=AvailableBalance-@Amount,HeldBalance=HeldBalance+@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId; SELECT @Balance=AvailableBalance FROM dbo.UserWallets WHERE UserId=@UserId;
INSERT dbo.Withdrawals(ReferenceNo,UserId,PaymentMethodId,Amount,FeePercent,FeeAmount,NetAmount,DestinationJson,DestinationDisplay,Status)
VALUES(@Ref,@UserId,@PaymentMethodId,@Amount,@FeePct,@Fee,@Net,@DestinationJson,@DestinationDisplay,0);
DECLARE @Id bigint=SCOPE_IDENTITY();
INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
VALUES(@UserId,N'WithdrawalDebit',@Ref,N'Completed withdrawal',0,@Amount,@Balance,N'Withdrawal',@Id,0);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Withdrawal request submitted and funds reserved.' Message,@Id Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id; END CATCH
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS BEGIN SET NOCOUNT ON;
SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId WHERE w.UserId=@UserId ORDER BY w.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS BEGIN SET NOCOUNT ON;
SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId ORDER BY CASE WHEN w.Status IN(0,1) THEN 0 ELSE 1 END,w.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_GetById @Id bigint
AS BEGIN SET NOCOUNT ON;
SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId WHERE w.Id=@Id;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Process @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRAN; DECLARE @Status int=(SELECT Status FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id);
IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
IF @Status<>0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Only a pending withdrawal can be marked processing.' Message,@Id Id; RETURN; END
UPDATE dbo.Withdrawals SET Status=1,AdminNote=@AdminNote,ReviewedBy=@AdminId,ProcessingAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Withdrawal.Process',N'Withdrawal',CONVERT(nvarchar(60),@Id),@AdminNote);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Withdrawal marked as processing.' Message,@Id Id; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Complete @Id bigint,@AdminId bigint,@PaymentReference nvarchar(150),@AdminNote nvarchar(500)=NULL
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
IF NULLIF(LTRIM(RTRIM(@PaymentReference)),N'') IS NULL BEGIN SELECT CAST(0 AS bit) Succeeded,N'Payment reference is required to complete a withdrawal.' Message,@Id Id; RETURN; END
BEGIN TRY BEGIN TRAN;
DECLARE @Status int,@UserId bigint,@Amount decimal(19,4); SELECT @Status=Status,@UserId=UserId,@Amount=Amount FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END
UPDATE dbo.UserWallets SET HeldBalance=HeldBalance-@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId AND HeldBalance>=@Amount;
IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END
UPDATE dbo.Withdrawals SET Status=3,AdminNote=@AdminNote,AdminPaymentReference=@PaymentReference,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
UPDATE dbo.WalletLedger SET IsVisible=1,Description=N'Completed withdrawal' WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Withdrawal.Complete',N'Withdrawal',CONVERT(nvarchar(60),@Id),@PaymentReference);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Withdrawal completed.' Message,@Id Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Reject @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
BEGIN TRY BEGIN TRAN;
DECLARE @Status int,@UserId bigint,@Amount decimal(19,4); SELECT @Status=Status,@UserId=UserId,@Amount=Amount FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END
UPDATE dbo.UserWallets SET AvailableBalance=AvailableBalance+@Amount,HeldBalance=HeldBalance-@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId AND HeldBalance>=@Amount;
IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END
UPDATE dbo.Withdrawals SET Status=4,AdminNote=@AdminNote,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
DELETE dbo.WalletLedger WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id AND IsVisible=0;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Withdrawal.Reject',N'Withdrawal',CONVERT(nvarchar(60),@Id),@AdminNote);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Withdrawal rejected and reserved funds returned.' Message,@Id Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN SET NOCOUNT ON;
SELECT u.FullName,w.AvailableBalance,w.HeldBalance,
ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
(SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
(SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals
FROM dbo.Users u JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Id=@UserId;
SELECT TOP(10) Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,CreatedAtUtc FROM dbo.WalletLedger WHERE UserId=@UserId AND IsVisible=1 ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Ledger_GetByUser @UserId bigint
AS BEGIN SET NOCOUNT ON; SELECT Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,CreatedAtUtc FROM dbo.WalletLedger WHERE UserId=@UserId AND IsVisible=1 ORDER BY CreatedAtUtc DESC,Id DESC; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Dashboard_Get
AS
BEGIN SET NOCOUNT ON;
SELECT (SELECT COUNT(*) FROM dbo.Users) TotalUsers,(SELECT COUNT(*) FROM dbo.Users WHERE Status=1) ActiveUsers,
(SELECT COUNT(*) FROM dbo.Deposits WHERE Status=0) PendingDeposits,(SELECT COUNT(*) FROM dbo.Withdrawals WHERE Status IN(0,1)) PendingWithdrawals,
ISNULL((SELECT SUM(AvailableBalance+HeldBalance) FROM dbo.UserWallets),0) TotalWalletBalance,
ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE Status=2 AND CAST(ReviewedAtUtc AS date)=CAST(SYSUTCDATETIME() AS date)),0) ApprovedDepositsToday,
ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE Status=3 AND CAST(CompletedAtUtc AS date)=CAST(SYSUTCDATETIME() AS date)),0) CompletedWithdrawalsToday;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Settings_Get
AS BEGIN SET NOCOUNT ON; SELECT DefaultWithdrawalMin,DefaultWithdrawalMax,DefaultWithdrawalFeePercent,SupportEmail,TelegramUrl FROM dbo.SystemSettings WHERE Id=1; END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Settings_Save @DefaultWithdrawalMin decimal(19,4),@DefaultWithdrawalMax decimal(19,4),@DefaultWithdrawalFeePercent decimal(9,4),@SupportEmail nvarchar(256),@TelegramUrl nvarchar(500),@AdminId bigint
AS
BEGIN SET NOCOUNT ON;
UPDATE dbo.SystemSettings SET DefaultWithdrawalMin=@DefaultWithdrawalMin,DefaultWithdrawalMax=@DefaultWithdrawalMax,DefaultWithdrawalFeePercent=@DefaultWithdrawalFeePercent,SupportEmail=@SupportEmail,TelegramUrl=@TelegramUrl,UpdatedAtUtc=SYSUTCDATETIME(),UpdatedBy=@AdminId WHERE Id=1;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId) VALUES(@AdminId,N'Settings.Update',N'SystemSettings',N'1');
END
GO

PRINT 'TahirFxTraderDb setup completed.';
PRINT 'Admin login: admin@fxtrader.local / Admin@123';
PRINT 'Change the admin password after first login.';
GO


/* ===== July 2026 patch: country/phone fields + company ledger ===== */
IF COL_LENGTH('dbo.Users','Country') IS NULL ALTER TABLE dbo.Users ADD Country nvarchar(80) NOT NULL CONSTRAINT DF_Users_Country DEFAULT(N'Pakistan');
GO
IF COL_LENGTH('dbo.Users','PhoneNumber') IS NULL ALTER TABLE dbo.Users ADD PhoneNumber nvarchar(30) NOT NULL CONSTRAINT DF_Users_Phone DEFAULT(N'');
GO
IF OBJECT_ID(N'dbo.CompanyWallets', N'U') IS NULL
CREATE TABLE dbo.CompanyWallets
(
    Id tinyint NOT NULL CONSTRAINT PK_CompanyWallets PRIMARY KEY,
    Balance decimal(19,4) NOT NULL CONSTRAINT DF_CompanyWallet_Balance DEFAULT(0),
    UpdatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_CompanyWallet_Updated DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT CK_CompanyWallet_Id CHECK(Id = 1)
);
GO
IF OBJECT_ID(N'dbo.CompanyLedger', N'U') IS NULL
CREATE TABLE dbo.CompanyLedger
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CompanyLedger PRIMARY KEY,
    EntryType nvarchar(40) NOT NULL,
    ReferenceNo nvarchar(40) NOT NULL,
    Description nvarchar(250) NOT NULL,
    Credit decimal(19,4) NOT NULL CONSTRAINT DF_CompanyLedger_Credit DEFAULT(0),
    Debit decimal(19,4) NOT NULL CONSTRAINT DF_CompanyLedger_Debit DEFAULT(0),
    BalanceAfter decimal(19,4) NOT NULL,
    RelatedEntityType nvarchar(30) NOT NULL,
    RelatedEntityId bigint NOT NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_CompanyLedger_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT CK_CompanyLedger_OneSide CHECK((Credit > 0 AND Debit = 0) OR (Debit > 0 AND Credit = 0))
);
GO
IF NOT EXISTS(SELECT 1 FROM dbo.CompanyWallets WHERE Id = 1) INSERT dbo.CompanyWallets(Id, Balance) VALUES(1, 0);
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_GetByEmail @Email nvarchar(256)
AS
BEGIN SET NOCOUNT ON;
SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
       ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,u.CreatedAtUtc
FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Email=LOWER(LTRIM(RTRIM(@Email)));
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_GetById @UserId bigint
AS
BEGIN SET NOCOUNT ON;
SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
       ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,u.CreatedAtUtc
FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Id=@UserId;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_Register @FullName nvarchar(120),@Country nvarchar(80),@PhoneNumber nvarchar(30),@Email nvarchar(256),@PasswordHash nvarchar(500)
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
SET @Email=LOWER(LTRIM(RTRIM(@Email)));
IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email) BEGIN SELECT CAST(0 AS bit) Succeeded,N'An account already exists with this email address.' Message,CAST(NULL AS bigint) Id; RETURN; END
BEGIN TRY BEGIN TRAN;
DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=N'User');
INSERT dbo.Users(RoleId,FullName,Country,PhoneNumber,Email,PasswordHash,Status,IsEmailVerified,CanDeposit,CanWithdraw) VALUES(@RoleId,LTRIM(RTRIM(@FullName)),LTRIM(RTRIM(@Country)),LTRIM(RTRIM(@PhoneNumber)),@Email,@PasswordHash,0,0,1,1);
DECLARE @Id bigint=SCOPE_IDENTITY(); INSERT dbo.UserWallets(UserId) VALUES(@Id);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Account created.' Message,@Id Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id; END CATCH
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Users_GetAll
AS BEGIN SET NOCOUNT ON;
SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,ISNULL(w.AvailableBalance,0) AvailableBalance,u.CreatedAtUtc
FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id ORDER BY u.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_Get @UserId bigint
AS
BEGIN SET NOCOUNT ON;
SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride
FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId WHERE u.Id=@UserId;
SELECT p.PermissionKey,CAST(ISNULL(o.IsAllowed,CASE WHEN rp.PermissionId IS NULL THEN 0 ELSE 1 END) AS bit) IsAllowed
FROM dbo.Permissions p CROSS JOIN dbo.Users u LEFT JOIN dbo.RolePermissions rp ON rp.RoleId=u.RoleId AND rp.PermissionId=p.Id
LEFT JOIN dbo.UserPermissionOverrides o ON o.UserId=u.Id AND o.PermissionId=p.Id WHERE u.Id=@UserId ORDER BY p.PermissionKey;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_Update
@UserId bigint,@FullName nvarchar(120),@Country nvarchar(80),@PhoneNumber nvarchar(30),@Email nvarchar(256),@RoleName nvarchar(50),@Status int,@IsEmailVerified bit,@CanDeposit bit,@CanWithdraw bit,
@WithdrawalMinOverride decimal(19,4)=NULL,@WithdrawalMaxOverride decimal(19,4)=NULL,@WithdrawalFeePercentOverride decimal(9,4)=NULL,@PermissionsJson nvarchar(max),@AdminId bigint
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
SET @Email=LOWER(LTRIM(RTRIM(@Email)));
IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email AND Id<>@UserId) BEGIN SELECT CAST(0 AS bit) Succeeded,N'This email address is already used by another user.' Message,@UserId Id; RETURN; END
DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=@RoleName);
IF @RoleId IS NULL BEGIN SELECT CAST(0 AS bit) Succeeded,N'Invalid role name.' Message,@UserId Id; RETURN; END
BEGIN TRY BEGIN TRAN;
UPDATE dbo.Users SET FullName=LTRIM(RTRIM(@FullName)),Country=LTRIM(RTRIM(@Country)),PhoneNumber=LTRIM(RTRIM(@PhoneNumber)),Email=@Email,RoleId=@RoleId,Status=@Status,IsEmailVerified=@IsEmailVerified,CanDeposit=@CanDeposit,CanWithdraw=@CanWithdraw,
WithdrawalMinOverride=@WithdrawalMinOverride,WithdrawalMaxOverride=@WithdrawalMaxOverride,WithdrawalFeePercentOverride=@WithdrawalFeePercentOverride,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=@UserId;
DELETE o FROM dbo.UserPermissionOverrides o WHERE o.UserId=@UserId;
INSERT dbo.UserPermissionOverrides(UserId,PermissionId,IsAllowed)
SELECT @UserId,p.Id,1 FROM OPENJSON(@PermissionsJson) WITH (PermissionKey nvarchar(100) '$') j JOIN dbo.Permissions p ON p.PermissionKey=j.PermissionKey;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId) VALUES(@AdminId,N'User.Update',N'User',CONVERT(nvarchar(60),@UserId));
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'User settings updated successfully.' Message,@UserId Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@UserId Id; END CATCH
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Approve @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
BEGIN TRY BEGIN TRAN;
DECLARE @Status int,@UserId bigint,@Net decimal(19,4),@Ref nvarchar(40),@Amount decimal(19,4),@UserBalance decimal(19,4),@CompanyBalance decimal(19,4);
SELECT @Status=Status,@UserId=UserId,@Net=NetAmount,@Ref=ReferenceNo,@Amount=Amount FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id; RETURN; END
IF @Status<>0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id; RETURN; END
UPDATE dbo.UserWallets SET AvailableBalance=AvailableBalance+@Net,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId; SELECT @UserBalance=AvailableBalance FROM dbo.UserWallets WHERE UserId=@UserId;
UPDATE dbo.Deposits SET Status=2,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
VALUES(@UserId,N'DepositCredit',@Ref,N'Approved deposit',@Net,0,@UserBalance,N'Deposit',@Id,1);
UPDATE dbo.CompanyWallets SET Balance=Balance+@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1; SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
VALUES(N'DepositReceipt',@Ref,N'Deposit received from user',@Amount,0,@CompanyBalance,N'Deposit',@Id);
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Deposit.Approve',N'Deposit',CONVERT(nvarchar(60),@Id),@AdminNote);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Deposit approved and user wallet credited.' Message,@Id Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Complete @Id bigint,@AdminId bigint,@PaymentReference nvarchar(150),@AdminNote nvarchar(500)=NULL
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
IF NULLIF(LTRIM(RTRIM(@PaymentReference)),N'') IS NULL BEGIN SELECT CAST(0 AS bit) Succeeded,N'Payment reference is required to complete a withdrawal.' Message,@Id Id; RETURN; END
BEGIN TRY BEGIN TRAN;
DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@FeeAmount decimal(19,4),@NetAmount decimal(19,4),@Ref nvarchar(40),@CompanyBalance decimal(19,4);
SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@FeeAmount=FeeAmount,@NetAmount=NetAmount,@Ref=ReferenceNo FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END
UPDATE dbo.UserWallets SET HeldBalance=HeldBalance-@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId AND HeldBalance>=@Amount;
IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END
UPDATE dbo.Withdrawals SET Status=3,AdminNote=@AdminNote,AdminPaymentReference=@PaymentReference,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
UPDATE dbo.WalletLedger SET IsVisible=1,Description=N'Completed withdrawal (includes fee deduction)' WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id;
UPDATE dbo.CompanyWallets SET Balance=Balance-@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1; SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
VALUES(N'WithdrawalSettlement',@Ref,N'Withdrawal settled to user (gross amount reserved)',0,@Amount,@CompanyBalance,N'Withdrawal',@Id);
IF @FeeAmount > 0
BEGIN
    UPDATE dbo.CompanyWallets SET Balance=Balance+@FeeAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1; SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
    INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
    VALUES(N'WithdrawalFee',@Ref,N'Withdrawal fee transferred to company wallet',@FeeAmount,0,@CompanyBalance,N'WithdrawalFee',@Id);
END
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Withdrawal.Complete',N'Withdrawal',CONVERT(nvarchar(60),@Id),@PaymentReference);
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'Withdrawal completed. Fee moved to company wallet and company ledger updated.' Message,@Id Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_CompanyLedger_Get
AS
BEGIN SET NOCOUNT ON;
SELECT Balance AS CurrentBalance FROM dbo.CompanyWallets WHERE Id = 1;
SELECT Id,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,CreatedAtUtc FROM dbo.CompanyLedger ORDER BY CreatedAtUtc DESC, Id DESC;
END
GO
PRINT 'Patch applied: country/phone fields and company ledger.';
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_Update
@UserId bigint,@FullName nvarchar(120),@Country nvarchar(80),@PhoneNumber nvarchar(30),@Email nvarchar(256),@RoleName nvarchar(50),@Status int,@IsEmailVerified bit,@CanDeposit bit,@CanWithdraw bit,
@WithdrawalMinOverride decimal(19,4)=NULL,@WithdrawalMaxOverride decimal(19,4)=NULL,@WithdrawalFeePercentOverride decimal(9,4)=NULL,@PermissionsJson nvarchar(max),@AdminId bigint
AS
BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
SET @Email=LOWER(LTRIM(RTRIM(@Email)));
IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email AND Id<>@UserId) BEGIN SELECT CAST(0 AS bit) Succeeded,N'This email address is already used by another user.' Message,@UserId Id; RETURN; END
DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=@RoleName);
IF @RoleId IS NULL BEGIN SELECT CAST(0 AS bit) Succeeded,N'Invalid role name.' Message,@UserId Id; RETURN; END
BEGIN TRY BEGIN TRAN;
UPDATE dbo.Users SET FullName=LTRIM(RTRIM(@FullName)),Country=LTRIM(RTRIM(@Country)),PhoneNumber=LTRIM(RTRIM(@PhoneNumber)),Email=@Email,RoleId=@RoleId,Status=@Status,IsEmailVerified=@IsEmailVerified,CanDeposit=@CanDeposit,CanWithdraw=@CanWithdraw,
WithdrawalMinOverride=@WithdrawalMinOverride,WithdrawalMaxOverride=@WithdrawalMaxOverride,WithdrawalFeePercentOverride=@WithdrawalFeePercentOverride,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=@UserId;
DELETE FROM dbo.UserPermissionOverrides WHERE UserId=@UserId;
DECLARE @Selected TABLE(PermissionKey nvarchar(100) PRIMARY KEY);
INSERT INTO @Selected(PermissionKey)
SELECT DISTINCT PermissionKey FROM OPENJSON(@PermissionsJson) WITH (PermissionKey nvarchar(100) '$');
INSERT dbo.UserPermissionOverrides(UserId,PermissionId,IsAllowed)
SELECT @UserId, p.Id, CASE WHEN s.PermissionKey IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END
FROM dbo.Permissions p LEFT JOIN @Selected s ON s.PermissionKey = p.PermissionKey;
INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId) VALUES(@AdminId,N'User.Update',N'User',CONVERT(nvarchar(60),@UserId));
COMMIT; SELECT CAST(1 AS bit) Succeeded,N'User settings updated successfully.' Message,@UserId Id;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@UserId Id; END CATCH
END
GO
USE TahirFxTraderDb;
GO

/* Separate investment and profit balances */
IF COL_LENGTH('dbo.UserWallets','InvestmentBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD InvestmentBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_Investment DEFAULT(0);
GO
IF COL_LENGTH('dbo.UserWallets','ProfitBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD ProfitBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_Profit DEFAULT(0);
GO
IF COL_LENGTH('dbo.UserWallets','HeldInvestmentBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD HeldInvestmentBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_HeldInvestment DEFAULT(0);
GO
IF COL_LENGTH('dbo.UserWallets','HeldProfitBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD HeldProfitBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_HeldProfit DEFAULT(0);
GO

/* Existing wallet values are treated as investment because old data had no profit split. */
UPDATE dbo.UserWallets
SET InvestmentBalance = AvailableBalance,
    ProfitBalance = 0,
    HeldInvestmentBalance = HeldBalance,
    HeldProfitBalance = 0
WHERE InvestmentBalance = 0
  AND ProfitBalance = 0
  AND HeldInvestmentBalance = 0
  AND HeldProfitBalance = 0
  AND (AvailableBalance <> 0 OR HeldBalance <> 0);
GO

IF COL_LENGTH('dbo.Withdrawals','ProfitAmount') IS NULL
    ALTER TABLE dbo.Withdrawals ADD ProfitAmount decimal(19,4) NOT NULL CONSTRAINT DF_Withdrawals_ProfitAmount DEFAULT(0);
GO
IF COL_LENGTH('dbo.Withdrawals','InvestmentAmount') IS NULL
    ALTER TABLE dbo.Withdrawals ADD InvestmentAmount decimal(19,4) NOT NULL CONSTRAINT DF_Withdrawals_InvestmentAmount DEFAULT(0);
GO

/* Existing pending withdrawals are considered investment withdrawals. */
UPDATE dbo.Withdrawals
SET InvestmentAmount = Amount,
    ProfitAmount = 0
WHERE InvestmentAmount = 0 AND ProfitAmount = 0;
GO

IF COL_LENGTH('dbo.WalletLedger','InvestmentBalanceAfter') IS NULL
    ALTER TABLE dbo.WalletLedger ADD InvestmentBalanceAfter decimal(19,4) NOT NULL CONSTRAINT DF_Ledger_InvestmentAfter DEFAULT(0);
GO
IF COL_LENGTH('dbo.WalletLedger','ProfitBalanceAfter') IS NULL
    ALTER TABLE dbo.WalletLedger ADD ProfitBalanceAfter decimal(19,4) NOT NULL CONSTRAINT DF_Ledger_ProfitAfter DEFAULT(0);
GO

/* Historical rows had no split; preserve their total as investment for display. */
UPDATE dbo.WalletLedger
SET InvestmentBalanceAfter = BalanceAfter,
    ProfitBalanceAfter = 0
WHERE InvestmentBalanceAfter = 0 AND ProfitBalanceAfter = 0 AND BalanceAfter <> 0;
GO

IF OBJECT_ID(N'dbo.ProfitReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.ProfitReferenceSeq AS bigint START WITH 1 INCREMENT BY 1;
GO

IF OBJECT_ID(N'dbo.ProfitAllocations', N'U') IS NULL
CREATE TABLE dbo.ProfitAllocations
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProfitAllocations PRIMARY KEY,
    ReferenceNo nvarchar(40) NOT NULL CONSTRAINT UQ_ProfitAllocations_Reference UNIQUE,
    UserId bigint NOT NULL,
    InvestmentBase decimal(19,4) NOT NULL,
    ProfitPercentage decimal(9,4) NOT NULL,
    ProfitAmount decimal(19,4) NOT NULL,
    AdminNote nvarchar(500) NULL,
    AddedBy bigint NOT NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ProfitAllocations_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_ProfitAllocations_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_ProfitAllocations_Admin FOREIGN KEY(AddedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_ProfitAllocations_Percentage CHECK(ProfitPercentage > 0 AND ProfitPercentage <= 100),
    CONSTRAINT CK_ProfitAllocations_Amounts CHECK(InvestmentBase > 0 AND ProfitAmount > 0)
);
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetByEmail @Email nvarchar(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Email=LOWER(LTRIM(RTRIM(@Email)));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetById @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Users_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    ORDER BY u.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalances_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    JOIN dbo.Roles r ON r.Id=u.RoleId
    WHERE r.Name=N'User'
    ORDER BY u.FullName,u.Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalance_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserProfit_Add
    @UserId bigint,
    @Percentage decimal(9,4),
    @Note nvarchar(500)=NULL,
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Percentage <= 0 OR @Percentage > 100
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'Profit percentage must be greater than 0 and not more than 100.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Investment decimal(19,4),@ProfitAmount decimal(19,4),@Available decimal(19,4),@ProfitBalance decimal(19,4),
                @Seq bigint,@Reference nvarchar(40),@AllocationId bigint,@UserStatus int;

        SELECT @Investment=w.InvestmentBalance,@UserStatus=u.Status
        FROM dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.Users u ON u.Id=w.UserId
        WHERE w.UserId=@UserId;

        IF @Investment IS NULL
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'User wallet was not found.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END
        IF @UserStatus<>1
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'Profit can only be added to an active user account.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END
        IF @Investment<=0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'This user has no available investment balance for profit calculation.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END

        SET @ProfitAmount=ROUND(@Investment*@Percentage/100.0,4);
        IF @ProfitAmount<=0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'The calculated profit is too small to credit.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END

        SET @Seq=NEXT VALUE FOR dbo.ProfitReferenceSeq;
        SET @Reference=N'PFT-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);

        INSERT dbo.ProfitAllocations(ReferenceNo,UserId,InvestmentBase,ProfitPercentage,ProfitAmount,AdminNote,AddedBy)
        VALUES(@Reference,@UserId,@Investment,@Percentage,@ProfitAmount,@Note,@AdminId);
        SET @AllocationId=SCOPE_IDENTITY();

        UPDATE dbo.UserWallets
        SET ProfitBalance=ProfitBalance+@ProfitAmount,
            AvailableBalance=AvailableBalance+@ProfitAmount,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId;

        SELECT @Available=AvailableBalance,@ProfitBalance=ProfitBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'ProfitCredit',@Reference,N'Profit credited at '+CONVERT(nvarchar(30),@Percentage)+N'%',@ProfitAmount,0,@Available,@Investment,@ProfitBalance,N'ProfitAllocation',@AllocationId,1);

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'User.Profit.Add',N'ProfitAllocation',CONVERT(nvarchar(60),@AllocationId),
               N'UserId='+CONVERT(nvarchar(30),@UserId)+N'; InvestmentBase='+CONVERT(nvarchar(50),@Investment)+N'; Percentage='+CONVERT(nvarchar(30),@Percentage)+N'; Profit='+CONVERT(nvarchar(50),@ProfitAmount));

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Profit of $'+CONVERT(nvarchar(50),CAST(@ProfitAmount AS decimal(19,2)))+N' credited on investment base $'+CONVERT(nvarchar(50),CAST(@Investment AS decimal(19,2)))+N'.' Message,
               @AllocationId Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Approve @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Net decimal(19,4),@Ref nvarchar(40),@Amount decimal(19,4),
                @UserBalance decimal(19,4),@InvestmentBalance decimal(19,4),@ProfitBalance decimal(19,4),@CompanyBalance decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Net=NetAmount,@Ref=ReferenceNo,@Amount=Amount
        FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id; RETURN; END
        IF @Status<>0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance+@Net,
            InvestmentBalance=InvestmentBalance+@Net,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId;

        SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        UPDATE dbo.Deposits SET Status=2,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'DepositCredit',@Ref,N'Approved deposit added to investment',@Net,0,@UserBalance,@InvestmentBalance,@ProfitBalance,N'Deposit',@Id,1);

        UPDATE dbo.CompanyWallets SET Balance=Balance+@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
        VALUES(N'DepositReceipt',@Ref,N'Deposit received from user',@Amount,0,@CompanyBalance,N'Deposit',@Id);

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'Deposit.Approve',N'Deposit',CONVERT(nvarchar(60),@Id),@AdminNote);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Deposit approved and added to user investment balance.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawal_Create
    @UserId bigint,
    @PaymentMethodId int,
    @Amount decimal(19,4),
    @DestinationJson nvarchar(max),
    @DestinationDisplay nvarchar(300)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF ISJSON(@DestinationJson)<>1
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'Withdrawal destination is invalid.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Can bit,@UserStatus int,@Verified bit,@UserMin decimal(19,4),@UserMax decimal(19,4),@UserFee decimal(9,4),
                @Available decimal(19,4),@Investment decimal(19,4),@Profit decimal(19,4),
                @GlobalMin decimal(19,4),@GlobalMax decimal(19,4),@GlobalFee decimal(9,4),
                @MethodMin decimal(19,4),@MethodMax decimal(19,4),@MethodFee decimal(9,4),@MethodActive bit,@Supports bit,
                @EffectiveMin decimal(19,4),@EffectiveMax decimal(19,4),@FeePct decimal(9,4),
                @ProfitUsed decimal(19,4),@InvestmentUsed decimal(19,4);

        SELECT @Can=u.CanWithdraw,@UserStatus=u.Status,@Verified=u.IsEmailVerified,@UserMin=u.WithdrawalMinOverride,
               @UserMax=u.WithdrawalMaxOverride,@UserFee=u.WithdrawalFeePercentOverride,
               @Available=w.AvailableBalance,@Investment=w.InvestmentBalance,@Profit=w.ProfitBalance
        FROM dbo.Users u
        JOIN dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id
        WHERE u.Id=@UserId;

        SELECT @GlobalMin=DefaultWithdrawalMin,@GlobalMax=DefaultWithdrawalMax,@GlobalFee=DefaultWithdrawalFeePercent
        FROM dbo.SystemSettings WHERE Id=1;
        SELECT @MethodMin=MinWithdrawal,@MethodMax=MaxWithdrawal,@MethodFee=WithdrawalFeePercent,@MethodActive=IsActive,@Supports=SupportsWithdrawal
        FROM dbo.PaymentMethods WHERE Id=@PaymentMethodId;

        IF ISNULL(@UserStatus,-1)<>1 OR ISNULL(@Verified,0)<>1 OR ISNULL(@Can,0)<>1
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawals are disabled for this account.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF ISNULL(@MethodActive,0)<>1 OR ISNULL(@Supports,0)<>1
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'The selected withdrawal method is unavailable.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @EffectiveMin=CASE WHEN ISNULL(@UserMin,@GlobalMin)>@MethodMin THEN ISNULL(@UserMin,@GlobalMin) ELSE @MethodMin END;
        SET @EffectiveMax=ISNULL(@UserMax,@GlobalMax);
        IF @MethodMax IS NOT NULL AND @MethodMax<@EffectiveMax SET @EffectiveMax=@MethodMax;
        SET @FeePct=COALESCE(@UserFee,NULLIF(@MethodFee,0),@GlobalFee);

        IF @Amount<@EffectiveMin OR @Amount>@EffectiveMax
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF @Available<@Amount OR (@Investment+@Profit)<@Amount
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Insufficient available balance.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @ProfitUsed=CASE WHEN @Profit>=@Amount THEN @Amount ELSE @Profit END;
        SET @InvestmentUsed=@Amount-@ProfitUsed;

        DECLARE @Fee decimal(19,4)=ROUND(@Amount*@FeePct/100.0,4),
                @Net decimal(19,4)=@Amount-ROUND(@Amount*@FeePct/100.0,4),
                @Seq bigint=NEXT VALUE FOR dbo.WithdrawalReferenceSeq,
                @Ref nvarchar(40),@Balance decimal(19,4),@InvestmentAfter decimal(19,4),@ProfitAfter decimal(19,4);
        IF @Net<=0
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount must be greater than the fee.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @Ref=N'WDL-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance-@Amount,
            HeldBalance=HeldBalance+@Amount,
            ProfitBalance=ProfitBalance-@ProfitUsed,
            InvestmentBalance=InvestmentBalance-@InvestmentUsed,
            HeldProfitBalance=HeldProfitBalance+@ProfitUsed,
            HeldInvestmentBalance=HeldInvestmentBalance+@InvestmentUsed,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId
          AND AvailableBalance>=@Amount
          AND ProfitBalance>=@ProfitUsed
          AND InvestmentBalance>=@InvestmentUsed;

        IF @@ROWCOUNT=0
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Wallet balances changed while the request was being processed. Please try again.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SELECT @Balance=AvailableBalance,@InvestmentAfter=InvestmentBalance,@ProfitAfter=ProfitBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        INSERT dbo.Withdrawals(ReferenceNo,UserId,PaymentMethodId,Amount,FeePercent,FeeAmount,NetAmount,ProfitAmount,InvestmentAmount,DestinationJson,DestinationDisplay,Status)
        VALUES(@Ref,@UserId,@PaymentMethodId,@Amount,@FeePct,@Fee,@Net,@ProfitUsed,@InvestmentUsed,@DestinationJson,@DestinationDisplay,0);
        DECLARE @Id bigint=SCOPE_IDENTITY();

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'WithdrawalDebit',@Ref,N'Completed withdrawal (profit used first)',0,@Amount,@Balance,@InvestmentAfter,@ProfitAfter,N'Withdrawal',@Id,0);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Withdrawal submitted. $'+CONVERT(nvarchar(50),CAST(@ProfitUsed AS decimal(19,2)))+N' reserved from profit and $'+CONVERT(nvarchar(50),CAST(@InvestmentUsed AS decimal(19,2)))+N' from investment.' Message,
               @Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Complete
    @Id bigint,
    @AdminId bigint,
    @PaymentReference nvarchar(150),
    @AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@PaymentReference)),N'') IS NULL
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Payment reference is required to complete a withdrawal.' Message,@Id Id; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@FeeAmount decimal(19,4),@NetAmount decimal(19,4),
                @ProfitAmount decimal(19,4),@InvestmentAmount decimal(19,4),@Ref nvarchar(40),@CompanyBalance decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@FeeAmount=FeeAmount,@NetAmount=NetAmount,
               @ProfitAmount=ProfitAmount,@InvestmentAmount=InvestmentAmount,@Ref=ReferenceNo
        FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;

        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
        IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET HeldBalance=HeldBalance-@Amount,
            HeldProfitBalance=HeldProfitBalance-@ProfitAmount,
            HeldInvestmentBalance=HeldInvestmentBalance-@InvestmentAmount,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId
          AND HeldBalance>=@Amount
          AND HeldProfitBalance>=@ProfitAmount
          AND HeldInvestmentBalance>=@InvestmentAmount;

        IF @@ROWCOUNT=0
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END

        UPDATE dbo.Withdrawals
        SET Status=3,AdminNote=@AdminNote,AdminPaymentReference=@PaymentReference,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME()
        WHERE Id=@Id;

        UPDATE dbo.WalletLedger
        SET IsVisible=1,
            Description=N'Completed withdrawal: profit $'+CONVERT(nvarchar(50),CAST(@ProfitAmount AS decimal(19,2)))+N', investment $'+CONVERT(nvarchar(50),CAST(@InvestmentAmount AS decimal(19,2)))
        WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id;

        UPDATE dbo.CompanyWallets SET Balance=Balance-@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
        VALUES(N'WithdrawalSettlement',@Ref,N'Withdrawal settled to user (gross amount reserved)',0,@Amount,@CompanyBalance,N'Withdrawal',@Id);

        IF @FeeAmount>0
        BEGIN
            UPDATE dbo.CompanyWallets SET Balance=Balance+@FeeAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
            SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
            INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
            VALUES(N'WithdrawalFee',@Ref,N'Withdrawal fee transferred to company wallet',@FeeAmount,0,@CompanyBalance,N'WithdrawalFee',@Id);
        END

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'Withdrawal.Complete',N'Withdrawal',CONVERT(nvarchar(60),@Id),@PaymentReference);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal completed. Profit was consumed before investment and the fee was credited to the company wallet.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Reject @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@ProfitAmount decimal(19,4),@InvestmentAmount decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@ProfitAmount=ProfitAmount,@InvestmentAmount=InvestmentAmount
        FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;

        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
        IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance+@Amount,
            HeldBalance=HeldBalance-@Amount,
            ProfitBalance=ProfitBalance+@ProfitAmount,
            InvestmentBalance=InvestmentBalance+@InvestmentAmount,
            HeldProfitBalance=HeldProfitBalance-@ProfitAmount,
            HeldInvestmentBalance=HeldInvestmentBalance-@InvestmentAmount,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId
          AND HeldBalance>=@Amount
          AND HeldProfitBalance>=@ProfitAmount
          AND HeldInvestmentBalance>=@InvestmentAmount;

        IF @@ROWCOUNT=0
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END

        UPDATE dbo.Withdrawals SET Status=4,AdminNote=@AdminNote,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        DELETE dbo.WalletLedger WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id AND IsVisible=0;
        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'Withdrawal.Reject',N'Withdrawal',CONVERT(nvarchar(60),@Id),@AdminNote);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal rejected and the original profit/investment split was restored.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.FullName,w.AvailableBalance,w.HeldBalance,w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,
           ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
           ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
           (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
           (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals
    FROM dbo.Users u JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Id=@UserId;

    SELECT TOP(10) Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Ledger_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

PRINT 'Investment/profit wallet upgrade completed.';
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.UserId=@UserId
    ORDER BY w.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    ORDER BY CASE WHEN w.Status IN(0,1) THEN 0 ELSE 1 END,w.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.Id=@Id;
END
GO
USE TahirFxTraderDb;
GO

/* Permanent user trace ID, e.g. USR-20260715-000001 */
IF COL_LENGTH('dbo.Users','UserTraceId') IS NULL
    ALTER TABLE dbo.Users ADD UserTraceId nvarchar(40) NULL;
GO

UPDATE dbo.Users
SET UserTraceId = N'USR-' + CONVERT(char(8), CreatedAtUtc, 112) + N'-' +
    CASE
        WHEN Id < 1000000 THEN RIGHT(N'000000' + CONVERT(nvarchar(20), Id), 6)
        ELSE CONVERT(nvarchar(20), Id)
    END
WHERE NULLIF(LTRIM(RTRIM(UserTraceId)), N'') IS NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = N'UX_Users_UserTraceId' AND object_id = OBJECT_ID(N'dbo.Users')
)
    CREATE UNIQUE INDEX UX_Users_UserTraceId ON dbo.Users(UserTraceId);
GO

ALTER TABLE dbo.Users ALTER COLUMN UserTraceId nvarchar(40) NOT NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetByEmail @Email nvarchar(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Email=LOWER(LTRIM(RTRIM(@Email)));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetById @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_Register
    @FullName nvarchar(120),
    @Country nvarchar(80),
    @PhoneNumber nvarchar(30),
    @Email nvarchar(256),
    @PasswordHash nvarchar(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Email=LOWER(LTRIM(RTRIM(@Email)));

    IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email)
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'An account already exists with this email address.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=N'User');
        DECLARE @Id bigint,@TraceId nvarchar(40);

        INSERT dbo.Users(RoleId,UserTraceId,FullName,Country,PhoneNumber,Email,PasswordHash,Status,IsEmailVerified,CanDeposit,CanWithdraw)
        VALUES(@RoleId,N'PENDING',LTRIM(RTRIM(@FullName)),LTRIM(RTRIM(@Country)),LTRIM(RTRIM(@PhoneNumber)),@Email,@PasswordHash,0,0,1,1);

        SET @Id=SCOPE_IDENTITY();
        SET @TraceId=N'USR-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+
            CASE WHEN @Id<1000000 THEN RIGHT(N'000000'+CONVERT(nvarchar(20),@Id),6) ELSE CONVERT(nvarchar(20),@Id) END;

        UPDATE dbo.Users SET UserTraceId=@TraceId WHERE Id=@Id;
        INSERT dbo.UserWallets(UserId) VALUES(@Id);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Account created. User ID: '+@TraceId Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Users_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    ORDER BY u.CreatedAtUtc DESC,u.Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride
    FROM dbo.Users u JOIN dbo.Roles r ON r.Id=u.RoleId WHERE u.Id=@UserId;

    SELECT p.PermissionKey,CAST(ISNULL(o.IsAllowed,CASE WHEN rp.PermissionId IS NULL THEN 0 ELSE 1 END) AS bit) IsAllowed
    FROM dbo.Permissions p
    CROSS JOIN dbo.Users u
    LEFT JOIN dbo.RolePermissions rp ON rp.RoleId=u.RoleId AND rp.PermissionId=p.Id
    LEFT JOIN dbo.UserPermissionOverrides o ON o.UserId=u.Id AND o.PermissionId=p.Id
    WHERE u.Id=@UserId ORDER BY p.PermissionKey;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_User_GetByTraceId @UserTraceId nvarchar(40)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.UserTraceId=UPPER(LTRIM(RTRIM(@UserTraceId)));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalances_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    JOIN dbo.Roles r ON r.Id=u.RoleId
    WHERE r.Name=N'User'
    ORDER BY u.FullName,u.Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalance_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.FullName,u.UserTraceId,w.AvailableBalance,w.HeldBalance,w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,
           ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
           ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
           (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
           (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals
    FROM dbo.Users u JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Id=@UserId;

    SELECT TOP(10) Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Deposits_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.Id,d.ReferenceNo,d.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,
           d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
    FROM dbo.Deposits d
    JOIN dbo.Users u ON u.Id=d.UserId
    JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId
    WHERE d.UserId=@UserId ORDER BY d.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposits_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.Id,d.ReferenceNo,d.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,
           d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
    FROM dbo.Deposits d
    JOIN dbo.Users u ON u.Id=d.UserId
    JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId
    ORDER BY CASE WHEN d.Status=0 THEN 0 ELSE 1 END,d.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.Id,d.ReferenceNo,d.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,d.PaymentMethodId,p.Name PaymentMethodName,
           d.Amount,d.FeeAmount,d.NetAmount,d.SenderAccount,d.TransactionReference,d.ScreenshotPath,d.Status,d.AdminNote,d.CreatedAtUtc,d.ReviewedAtUtc
    FROM dbo.Deposits d
    JOIN dbo.Users u ON u.Id=d.UserId
    JOIN dbo.PaymentMethods p ON p.Id=d.PaymentMethodId
    WHERE d.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.UserId=@UserId ORDER BY w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    ORDER BY CASE WHEN w.Status IN(0,1) THEN 0 ELSE 1 END,w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id=w.UserId
    JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.Id=@Id;
END
GO

PRINT 'User trace ID upgrade completed.';
GO

/* Corrected permanent trace sequence and registration procedure */

IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
BEGIN
    DECLARE @UserTraceStart bigint = ISNULL((SELECT MAX(Id) FROM dbo.Users),0) + 1;
    DECLARE @UserTraceSql nvarchar(max);
    SET @UserTraceSql = N'CREATE SEQUENCE dbo.UserTraceReferenceSeq AS bigint START WITH ' +
                        CONVERT(nvarchar(30), @UserTraceStart) +
                        N' INCREMENT BY 1 NO CYCLE;';
    EXEC sys.sp_executesql @UserTraceSql;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_User_Register
    @FullName nvarchar(120),
    @Country nvarchar(80),
    @PhoneNumber nvarchar(30),
    @Email nvarchar(256),
    @PasswordHash nvarchar(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Email=LOWER(LTRIM(RTRIM(@Email)));

    IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email)
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'An account already exists with this email address.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=N'User');
        DECLARE @Id bigint,@TraceId nvarchar(40),@TraceSequence bigint;
        SET @TraceSequence=NEXT VALUE FOR dbo.UserTraceReferenceSeq;

        SET @TraceId=N'USR-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+
            CASE WHEN @TraceSequence<1000000 THEN RIGHT(N'000000'+CONVERT(nvarchar(20),@TraceSequence),6) ELSE CONVERT(nvarchar(20),@TraceSequence) END;

        INSERT dbo.Users(RoleId,UserTraceId,FullName,Country,PhoneNumber,Email,PasswordHash,Status,IsEmailVerified,CanDeposit,CanWithdraw)
        VALUES(@RoleId,@TraceId,LTRIM(RTRIM(@FullName)),LTRIM(RTRIM(@Country)),LTRIM(RTRIM(@PhoneNumber)),@Email,@PasswordHash,0,0,1,1);

        SET @Id=SCOPE_IDENTITY();
        INSERT dbo.UserWallets(UserId) VALUES(@Id);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Account created. User ID: '+@TraceId Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

USE TahirFxTraderDb;
GO

/* Bulk profit allocation: one percentage applied to all eligible active users. */
IF OBJECT_ID(N'dbo.ProfitAllocations', N'U') IS NULL
BEGIN
    ;THROW 50001, 'Run ProfitBalanceUpgrade.sql before BulkProfitUpgrade.sql.', 1;
END
GO

IF OBJECT_ID(N'dbo.ProfitBatchReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.ProfitBatchReferenceSeq AS bigint START WITH 1 INCREMENT BY 1;
GO

IF OBJECT_ID(N'dbo.ProfitBatches', N'U') IS NULL
CREATE TABLE dbo.ProfitBatches
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProfitBatches PRIMARY KEY,
    BatchReference nvarchar(40) NOT NULL CONSTRAINT UQ_ProfitBatches_Reference UNIQUE,
    ProfitPercentage decimal(9,4) NOT NULL,
    EligibleUserCount int NOT NULL,
    TotalInvestmentBase decimal(38,4) NOT NULL,
    TotalProfitAmount decimal(38,4) NOT NULL,
    AdminNote nvarchar(500) NULL,
    AddedBy bigint NOT NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ProfitBatches_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_ProfitBatches_Admin FOREIGN KEY(AddedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_ProfitBatches_Percentage CHECK(ProfitPercentage > 0 AND ProfitPercentage <= 100),
    CONSTRAINT CK_ProfitBatches_Totals CHECK(EligibleUserCount > 0 AND TotalInvestmentBase > 0 AND TotalProfitAmount > 0)
);
GO

IF COL_LENGTH('dbo.ProfitAllocations','BatchId') IS NULL
    ALTER TABLE dbo.ProfitAllocations ADD BatchId bigint NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name=N'FK_ProfitAllocations_Batch' AND parent_object_id=OBJECT_ID(N'dbo.ProfitAllocations')
)
    ALTER TABLE dbo.ProfitAllocations WITH CHECK
    ADD CONSTRAINT FK_ProfitAllocations_Batch FOREIGN KEY(BatchId) REFERENCES dbo.ProfitBatches(Id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'IX_ProfitAllocations_BatchId' AND object_id=OBJECT_ID(N'dbo.ProfitAllocations')
)
    CREATE INDEX IX_ProfitAllocations_BatchId ON dbo.ProfitAllocations(BatchId, UserId);
GO


CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalances_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    JOIN dbo.Roles r ON r.Id=u.RoleId
    WHERE r.Name=N'User'
    ORDER BY u.FullName,u.Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalance_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserProfit_AddAll
    @Percentage decimal(9,4),
    @Note nvarchar(500)=NULL,
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Percentage <= 0 OR @Percentage > 100
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,
               N'Profit percentage must be greater than 0 and not more than 100.' Message,
               CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        CREATE TABLE #Eligible
        (
            UserId bigint NOT NULL PRIMARY KEY,
            InvestmentBase decimal(19,4) NOT NULL,
            ProfitAmount decimal(19,4) NOT NULL
        );

        INSERT #Eligible(UserId,InvestmentBase,ProfitAmount)
        SELECT u.Id,
               w.InvestmentBalance,
               ROUND(w.InvestmentBalance*@Percentage/100.0,4)
        FROM dbo.Users u
        JOIN dbo.Roles r ON r.Id=u.RoleId
        JOIN dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id
        WHERE r.Name=N'User'
          AND u.Status=1
          AND w.InvestmentBalance>0
          AND ROUND(w.InvestmentBalance*@Percentage/100.0,4)>0;

        DECLARE @EligibleCount int=(SELECT COUNT(*) FROM #Eligible),
                @TotalInvestment decimal(38,4)=(SELECT COALESCE(SUM(CONVERT(decimal(38,4),InvestmentBase)),0) FROM #Eligible),
                @TotalProfit decimal(38,4)=(SELECT COALESCE(SUM(CONVERT(decimal(38,4),ProfitAmount)),0) FROM #Eligible);

        IF @EligibleCount=0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'No active users currently have an available investment balance for profit calculation.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        DECLARE @BatchSeq bigint=NEXT VALUE FOR dbo.ProfitBatchReferenceSeq,
                @BatchReference nvarchar(40),
                @BatchId bigint;

        SET @BatchReference=N'PFB-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@BatchSeq),6);

        INSERT dbo.ProfitBatches(BatchReference,ProfitPercentage,EligibleUserCount,TotalInvestmentBase,TotalProfitAmount,AdminNote,AddedBy)
        VALUES(@BatchReference,@Percentage,@EligibleCount,@TotalInvestment,@TotalProfit,@Note,@AdminId);
        SET @BatchId=SCOPE_IDENTITY();

        DECLARE @Allocated TABLE
        (
            AllocationId bigint NOT NULL,
            UserId bigint NOT NULL,
            ReferenceNo nvarchar(40) NOT NULL,
            InvestmentBase decimal(19,4) NOT NULL,
            ProfitAmount decimal(19,4) NOT NULL
        );

        INSERT dbo.ProfitAllocations(ReferenceNo,UserId,InvestmentBase,ProfitPercentage,ProfitAmount,AdminNote,AddedBy,BatchId)
        OUTPUT inserted.Id,inserted.UserId,inserted.ReferenceNo,inserted.InvestmentBase,inserted.ProfitAmount
        INTO @Allocated(AllocationId,UserId,ReferenceNo,InvestmentBase,ProfitAmount)
        SELECT N'PFT-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),NEXT VALUE FOR dbo.ProfitReferenceSeq),6),
               e.UserId,e.InvestmentBase,@Percentage,e.ProfitAmount,@Note,@AdminId,@BatchId
        FROM #Eligible e;

        UPDATE w
        SET w.ProfitBalance=w.ProfitBalance+e.ProfitAmount,
            w.AvailableBalance=w.AvailableBalance+e.ProfitAmount,
            w.UpdatedAtUtc=SYSUTCDATETIME()
        FROM dbo.UserWallets w
        JOIN #Eligible e ON e.UserId=w.UserId;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        SELECT a.UserId,
               N'ProfitCredit',
               a.ReferenceNo,
               N'Bulk profit credited at '+CONVERT(nvarchar(30),@Percentage)+N'% (batch '+@BatchReference+N')',
               a.ProfitAmount,
               0,
               w.AvailableBalance,
               w.InvestmentBalance,
               w.ProfitBalance,
               N'ProfitAllocation',
               a.AllocationId,
               1
        FROM @Allocated a
        JOIN dbo.UserWallets w ON w.UserId=a.UserId;

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'User.Profit.AddAll',N'ProfitBatch',CONVERT(nvarchar(60),@BatchId),
               N'Batch='+@BatchReference+N'; EligibleUsers='+CONVERT(nvarchar(20),@EligibleCount)+
               N'; InvestmentBase='+CONVERT(nvarchar(60),@TotalInvestment)+
               N'; Percentage='+CONVERT(nvarchar(30),@Percentage)+
               N'; TotalProfit='+CONVERT(nvarchar(60),@TotalProfit));

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Bulk profit batch '+@BatchReference+N' completed. '+CONVERT(nvarchar(20),@EligibleCount)+
               N' users received $'+CONVERT(nvarchar(60),CAST(@TotalProfit AS decimal(38,2)))+
               N' total profit on $'+CONVERT(nvarchar(60),CAST(@TotalInvestment AS decimal(38,2)))+N' investment.' Message,
               @BatchId Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

PRINT 'Bulk profit allocation upgrade completed.';
GO



/* Final prerequisite guard for permanent user trace IDs. */
IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
BEGIN
    DECLARE @FinalUserTraceStart bigint = ISNULL((SELECT MAX(Id) FROM dbo.Users), 0) + 1;
    DECLARE @FinalUserTraceSql nvarchar(max);
    IF @FinalUserTraceStart < 1 SET @FinalUserTraceStart = 1;
    SET @FinalUserTraceSql = N'CREATE SEQUENCE dbo.UserTraceReferenceSeq AS bigint START WITH ' +
                             CONVERT(nvarchar(30), @FinalUserTraceStart) +
                             N' INCREMENT BY 1 NO CYCLE;';
    EXEC sys.sp_executesql @FinalUserTraceSql;
END
GO


/*
  OLX Trade - Referral Program Upgrade
  Run this script against the same TahirFxTraderDb used by the web application.
  Safe to rerun.

  Business rules:
  - A referral relationship is created during registration from the referrer's UserTraceId.
  - The referral is counted only after the referred user's first deposit is approved.
  - Welcome bonus and referral commission are calculated once from that first deposit amount.
  - Both credits are added to ProfitBalance, not InvestmentBalance.
*/
USE TahirFxTraderDb;
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    THROW 51001, 'dbo.Users was not found. Run the base database scripts first.', 1;
END
GO
IF OBJECT_ID(N'dbo.UserWallets', N'U') IS NULL OR COL_LENGTH('dbo.UserWallets','ProfitBalance') IS NULL
BEGIN
    THROW 51002, 'Profit balance tables are missing. Run ProfitBalanceUpgrade.sql first.', 1;
END
GO
IF OBJECT_ID(N'dbo.Deposits', N'U') IS NULL
BEGIN
    THROW 51003, 'dbo.Deposits was not found. Run the base database scripts first.', 1;
END
GO

/* Admin-controlled percentages. */
IF COL_LENGTH('dbo.SystemSettings','WelcomeBonusPercent') IS NULL
    ALTER TABLE dbo.SystemSettings ADD WelcomeBonusPercent decimal(9,4) NOT NULL CONSTRAINT DF_SystemSettings_WelcomeBonus DEFAULT(0);
GO
IF COL_LENGTH('dbo.SystemSettings','ReferralCommissionPercent') IS NULL
    ALTER TABLE dbo.SystemSettings ADD ReferralCommissionPercent decimal(9,4) NOT NULL CONSTRAINT DF_SystemSettings_ReferralCommission DEFAULT(0);
GO

/* Permanent registration relationship. */
IF COL_LENGTH('dbo.Users','ReferredByUserId') IS NULL
    ALTER TABLE dbo.Users ADD ReferredByUserId bigint NULL;
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name=N'FK_Users_ReferredByUser' AND parent_object_id=OBJECT_ID(N'dbo.Users')
)
    ALTER TABLE dbo.Users WITH CHECK
    ADD CONSTRAINT FK_Users_ReferredByUser FOREIGN KEY(ReferredByUserId) REFERENCES dbo.Users(Id);
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'IX_Users_ReferredByUserId' AND object_id=OBJECT_ID(N'dbo.Users')
)
    CREATE INDEX IX_Users_ReferredByUserId ON dbo.Users(ReferredByUserId) WHERE ReferredByUserId IS NOT NULL;
GO

IF OBJECT_ID(N'dbo.WelcomeBonusReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.WelcomeBonusReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.ReferralCommissionReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.ReferralCommissionReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO

IF OBJECT_ID(N'dbo.Referrals', N'U') IS NULL
CREATE TABLE dbo.Referrals
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Referrals PRIMARY KEY,
    ReferrerUserId bigint NOT NULL,
    ReferredUserId bigint NOT NULL,
    ReferralCodeUsed nvarchar(40) NOT NULL,
    IsQualified bit NOT NULL CONSTRAINT DF_Referrals_Qualified DEFAULT(0),
    FirstDepositId bigint NULL,
    FirstDepositAmount decimal(19,4) NOT NULL CONSTRAINT DF_Referrals_FirstDepositAmount DEFAULT(0),
    WelcomeBonusPercent decimal(9,4) NOT NULL CONSTRAINT DF_Referrals_WelcomePercent DEFAULT(0),
    WelcomeBonusAmount decimal(19,4) NOT NULL CONSTRAINT DF_Referrals_WelcomeAmount DEFAULT(0),
    WelcomeBonusReferenceNo nvarchar(40) NULL,
    ReferralCommissionPercent decimal(9,4) NOT NULL CONSTRAINT DF_Referrals_CommissionPercent DEFAULT(0),
    ReferralCommissionAmount decimal(19,4) NOT NULL CONSTRAINT DF_Referrals_CommissionAmount DEFAULT(0),
    ReferralCommissionReferenceNo nvarchar(40) NULL,
    RegisteredAtUtc datetime2(0) NOT NULL CONSTRAINT DF_Referrals_Registered DEFAULT(SYSUTCDATETIME()),
    QualifiedAtUtc datetime2(0) NULL,
    CONSTRAINT UQ_Referrals_ReferredUser UNIQUE(ReferredUserId),
    CONSTRAINT FK_Referrals_Referrer FOREIGN KEY(ReferrerUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Referrals_Referred FOREIGN KEY(ReferredUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Referrals_Deposit FOREIGN KEY(FirstDepositId) REFERENCES dbo.Deposits(Id),
    CONSTRAINT CK_Referrals_DifferentUsers CHECK(ReferrerUserId<>ReferredUserId),
    CONSTRAINT CK_Referrals_Amounts CHECK(FirstDepositAmount>=0 AND WelcomeBonusAmount>=0 AND ReferralCommissionAmount>=0),
    CONSTRAINT CK_Referrals_Percentages CHECK(WelcomeBonusPercent>=0 AND WelcomeBonusPercent<=100 AND ReferralCommissionPercent>=0 AND ReferralCommissionPercent<=100)
);
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'IX_Referrals_Referrer_Qualified' AND object_id=OBJECT_ID(N'dbo.Referrals')
)
    CREATE INDEX IX_Referrals_Referrer_Qualified ON dbo.Referrals(ReferrerUserId,IsQualified,QualifiedAtUtc DESC);
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name=N'UX_Referrals_FirstDeposit' AND object_id=OBJECT_ID(N'dbo.Referrals')
)
    CREATE UNIQUE INDEX UX_Referrals_FirstDeposit ON dbo.Referrals(FirstDepositId) WHERE FirstDepositId IS NOT NULL;
GO

IF OBJECT_ID(N'dbo.WelcomeBonuses', N'U') IS NULL
CREATE TABLE dbo.WelcomeBonuses
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_WelcomeBonuses PRIMARY KEY,
    ReferenceNo nvarchar(40) NOT NULL CONSTRAINT UQ_WelcomeBonuses_Reference UNIQUE,
    UserId bigint NOT NULL,
    DepositId bigint NOT NULL,
    DepositAmount decimal(19,4) NOT NULL,
    BonusPercent decimal(9,4) NOT NULL,
    BonusAmount decimal(19,4) NOT NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_WelcomeBonuses_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT UQ_WelcomeBonuses_Deposit UNIQUE(DepositId),
    CONSTRAINT FK_WelcomeBonuses_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_WelcomeBonuses_Deposit FOREIGN KEY(DepositId) REFERENCES dbo.Deposits(Id),
    CONSTRAINT CK_WelcomeBonuses_Values CHECK(DepositAmount>0 AND BonusPercent>0 AND BonusPercent<=100 AND BonusAmount>0)
);
GO

/* Registration supports an optional referrer UserTraceId. */
CREATE OR ALTER PROCEDURE dbo.sp_User_Register
    @FullName nvarchar(120),
    @Country nvarchar(80),
    @PhoneNumber nvarchar(30),
    @Email nvarchar(256),
    @PasswordHash nvarchar(500),
    @ReferralCode nvarchar(40)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Email=LOWER(LTRIM(RTRIM(@Email)));
    SET @ReferralCode=NULLIF(UPPER(LTRIM(RTRIM(@ReferralCode))),N'');

    IF EXISTS(SELECT 1 FROM dbo.Users WHERE Email=@Email)
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,N'An account already exists with this email address.' Message,CAST(NULL AS bigint) Id;
        RETURN;
    END

    DECLARE @ReferrerUserId bigint=NULL;
    IF @ReferralCode IS NOT NULL
    BEGIN
        SELECT @ReferrerUserId=u.Id
        FROM dbo.Users u
        JOIN dbo.Roles r ON r.Id=u.RoleId
        WHERE u.UserTraceId=@ReferralCode AND r.Name=N'User' AND u.Status=1;

        IF @ReferrerUserId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) Succeeded,N'The referral code is invalid or the referrer account is not active.' Message,CAST(NULL AS bigint) Id;
            RETURN;
        END
    END

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @RoleId int=(SELECT Id FROM dbo.Roles WHERE Name=N'User');
        DECLARE @Id bigint,@TraceId nvarchar(40),@PendingTrace nvarchar(40);
        SET @PendingTrace=N'PENDING-'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'');

        INSERT dbo.Users(RoleId,UserTraceId,FullName,Country,PhoneNumber,Email,PasswordHash,Status,IsEmailVerified,CanDeposit,CanWithdraw,ReferredByUserId)
        VALUES(@RoleId,@PendingTrace,LTRIM(RTRIM(@FullName)),LTRIM(RTRIM(@Country)),LTRIM(RTRIM(@PhoneNumber)),@Email,@PasswordHash,0,0,1,1,@ReferrerUserId);

        SET @Id=SCOPE_IDENTITY();
        SET @TraceId=N'USR-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+
            CASE WHEN @Id<1000000 THEN RIGHT(N'000000'+CONVERT(nvarchar(20),@Id),6) ELSE CONVERT(nvarchar(20),@Id) END;

        UPDATE dbo.Users SET UserTraceId=@TraceId WHERE Id=@Id;
        INSERT dbo.UserWallets(UserId) VALUES(@Id);

        IF @ReferrerUserId IS NOT NULL
            INSERT dbo.Referrals(ReferrerUserId,ReferredUserId,ReferralCodeUsed)
            VALUES(@ReferrerUserId,@Id,@ReferralCode);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Account created. User ID: '+@TraceId+
               CASE WHEN @ReferrerUserId IS NULL THEN N'' ELSE N'. Referral recorded and will qualify after the first approved deposit.' END Message,
               @Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

/* First approved deposit: investment credit + one-time welcome/referral rewards. */
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Approve
    @Id bigint,
    @AdminId bigint,
    @AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Status int,@UserId bigint,@Net decimal(19,4),@Ref nvarchar(40),@Amount decimal(19,4),
                @UserBalance decimal(19,4),@InvestmentBalance decimal(19,4),@ProfitBalance decimal(19,4),@CompanyBalance decimal(19,4),
                @IsFirstApprovedDeposit bit=0;

        SELECT @Status=Status,@UserId=UserId,@Net=NetAmount,@Ref=ReferenceNo,@Amount=Amount
        FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK)
        WHERE Id=@Id;

        IF @Status IS NULL
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id;
            RETURN;
        END
        IF @Status<>0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id;
            RETURN;
        END

        /* Updating the wallet serializes approvals for the same user. */
        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance+@Net,
            InvestmentBalance=InvestmentBalance+@Net,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId;

        IF @@ROWCOUNT=0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,N'User wallet was not found.' Message,@Id Id;
            RETURN;
        END

        SET @IsFirstApprovedDeposit=
            CASE WHEN EXISTS(SELECT 1 FROM dbo.Deposits WHERE UserId=@UserId AND Status=2) THEN 0 ELSE 1 END;

        SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        UPDATE dbo.Deposits
        SET Status=2,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME()
        WHERE Id=@Id;

        INSERT dbo.WalletLedger
        (UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES
        (@UserId,N'DepositCredit',@Ref,N'Approved deposit added to investment',@Net,0,@UserBalance,@InvestmentBalance,@ProfitBalance,N'Deposit',@Id,1);

        UPDATE dbo.CompanyWallets
        SET Balance=Balance+@Amount,UpdatedAtUtc=SYSUTCDATETIME()
        WHERE Id=1;

        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId)
        VALUES(N'DepositReceipt',@Ref,N'Deposit received from user',@Amount,0,@CompanyBalance,N'Deposit',@Id);

        IF @IsFirstApprovedDeposit=1
        BEGIN
            DECLARE @WelcomePercent decimal(9,4)=0,@ReferralPercent decimal(9,4)=0,
                    @WelcomeAmount decimal(19,4)=0,@ReferralAmount decimal(19,4)=0,
                    @WelcomeReference nvarchar(40)=NULL,@ReferralReference nvarchar(40)=NULL,
                    @WelcomeBonusId bigint=NULL,@ReferralId bigint=NULL,@ReferrerUserId bigint=NULL,
                    @ReferrerBalance decimal(19,4),@ReferrerInvestment decimal(19,4),@ReferrerProfit decimal(19,4),
                    @Sequence bigint;

            SELECT @WelcomePercent=WelcomeBonusPercent,@ReferralPercent=ReferralCommissionPercent
            FROM dbo.SystemSettings WITH(HOLDLOCK)
            WHERE Id=1;

            SET @WelcomeAmount=ROUND(@Amount*@WelcomePercent/100.0,4);

            IF @WelcomeAmount>0
            BEGIN
                SET @Sequence=NEXT VALUE FOR dbo.WelcomeBonusReferenceSeq;
                SET @WelcomeReference=N'WLB-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Sequence),6);

                INSERT dbo.WelcomeBonuses(ReferenceNo,UserId,DepositId,DepositAmount,BonusPercent,BonusAmount)
                VALUES(@WelcomeReference,@UserId,@Id,@Amount,@WelcomePercent,@WelcomeAmount);
                SET @WelcomeBonusId=SCOPE_IDENTITY();

                UPDATE dbo.UserWallets
                SET ProfitBalance=ProfitBalance+@WelcomeAmount,
                    AvailableBalance=AvailableBalance+@WelcomeAmount,
                    UpdatedAtUtc=SYSUTCDATETIME()
                WHERE UserId=@UserId;

                SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance
                FROM dbo.UserWallets WHERE UserId=@UserId;

                INSERT dbo.WalletLedger
                (UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
                VALUES
                (@UserId,N'WelcomeBonus',@WelcomeReference,N'Welcome bonus on first approved deposit',@WelcomeAmount,0,@UserBalance,@InvestmentBalance,@ProfitBalance,N'WelcomeBonus',@WelcomeBonusId,1);
            END

            SELECT @ReferralId=Id,@ReferrerUserId=ReferrerUserId
            FROM dbo.Referrals WITH(UPDLOCK,HOLDLOCK)
            WHERE ReferredUserId=@UserId AND IsQualified=0;

            IF @ReferralId IS NOT NULL
            BEGIN
                SET @ReferralAmount=ROUND(@Amount*@ReferralPercent/100.0,4);

                IF @ReferralAmount>0
                BEGIN
                    SET @Sequence=NEXT VALUE FOR dbo.ReferralCommissionReferenceSeq;
                    SET @ReferralReference=N'RFC-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Sequence),6);

                    UPDATE dbo.UserWallets
                    SET ProfitBalance=ProfitBalance+@ReferralAmount,
                        AvailableBalance=AvailableBalance+@ReferralAmount,
                        UpdatedAtUtc=SYSUTCDATETIME()
                    WHERE UserId=@ReferrerUserId;

                    IF @@ROWCOUNT=0
                    BEGIN
                        ROLLBACK;
                        SELECT CAST(0 AS bit) Succeeded,N'Referrer wallet was not found. No deposit changes were committed.' Message,@Id Id;
                        RETURN;
                    END

                    SELECT @ReferrerBalance=AvailableBalance,@ReferrerInvestment=InvestmentBalance,@ReferrerProfit=ProfitBalance
                    FROM dbo.UserWallets WHERE UserId=@ReferrerUserId;

                    INSERT dbo.WalletLedger
                    (UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
                    VALUES
                    (@ReferrerUserId,N'ReferralCommission',@ReferralReference,N'Referral commission after referred user first deposit',@ReferralAmount,0,@ReferrerBalance,@ReferrerInvestment,@ReferrerProfit,N'Referral',@ReferralId,1);
                END

                UPDATE dbo.Referrals
                SET IsQualified=1,
                    FirstDepositId=@Id,
                    FirstDepositAmount=@Amount,
                    WelcomeBonusPercent=@WelcomePercent,
                    WelcomeBonusAmount=@WelcomeAmount,
                    WelcomeBonusReferenceNo=@WelcomeReference,
                    ReferralCommissionPercent=@ReferralPercent,
                    ReferralCommissionAmount=@ReferralAmount,
                    ReferralCommissionReferenceNo=@ReferralReference,
                    QualifiedAtUtc=SYSUTCDATETIME()
                WHERE Id=@ReferralId;
            END
        END

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'Deposit.Approve',N'Deposit',CONVERT(nvarchar(60),@Id),
               COALESCE(@AdminNote,N'')+CASE WHEN @IsFirstApprovedDeposit=1 THEN N'; First deposit rewards evaluated.' ELSE N'' END);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Deposit approved and added to user investment balance.'+
               CASE WHEN @IsFirstApprovedDeposit=1 THEN N' First-deposit welcome and referral rewards were applied according to current settings.' ELSE N'' END Message,
               @Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

/* User dashboard includes qualified referral count and total commission earned. */
CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.FullName,u.UserTraceId,w.AvailableBalance,w.HeldBalance,w.InvestmentBalance,w.ProfitBalance,w.HeldInvestmentBalance,w.HeldProfitBalance,
           ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
           ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
           (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
           (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals,
           (SELECT COUNT(*) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1) SuccessfulReferralCount,
           ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1),0) ReferralCommissionEarned
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;

    SELECT TOP(10) Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ReferralDashboard_Get
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.WelcomeBonusPercent,s.ReferralCommissionPercent,
           (SELECT COUNT(*) FROM dbo.Referrals) RegisteredReferralCount,
           (SELECT COUNT(*) FROM dbo.Referrals WHERE IsQualified=1) QualifiedReferralCount,
           ISNULL((SELECT SUM(BonusAmount) FROM dbo.WelcomeBonuses),0) TotalWelcomeBonusPaid,
           ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE IsQualified=1),0) TotalReferralCommissionPaid
    FROM dbo.SystemSettings s
    WHERE s.Id=1;

    SELECT TOP(250)
           rf.Id,
           referrer.UserTraceId ReferrerTraceId,
           referrer.FullName ReferrerName,
           referred.UserTraceId ReferredTraceId,
           referred.FullName ReferredName,
           rf.IsQualified,
           rf.FirstDepositAmount,
           rf.WelcomeBonusAmount,
           rf.ReferralCommissionAmount,
           rf.RegisteredAtUtc,
           rf.QualifiedAtUtc
    FROM dbo.Referrals rf
    JOIN dbo.Users referrer ON referrer.Id=rf.ReferrerUserId
    JOIN dbo.Users referred ON referred.Id=rf.ReferredUserId
    ORDER BY rf.RegisteredAtUtc DESC,rf.Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_WelcomeBonusSettings_Save
    @Percentage decimal(9,4),
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    IF @Percentage<0 OR @Percentage>100
    BEGIN
        THROW 51004, 'Welcome bonus percentage must be between 0 and 100.', 1;
    END

    UPDATE dbo.SystemSettings
    SET WelcomeBonusPercent=@Percentage,UpdatedAtUtc=SYSUTCDATETIME(),UpdatedBy=@AdminId
    WHERE Id=1;

    INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
    VALUES(@AdminId,N'Referral.WelcomeBonus.Update',N'SystemSettings',N'1',N'WelcomeBonusPercent='+CONVERT(nvarchar(30),@Percentage));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ReferralCommissionSettings_Save
    @Percentage decimal(9,4),
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    IF @Percentage<0 OR @Percentage>100
    BEGIN
        THROW 51005, 'Referral commission percentage must be between 0 and 100.', 1;
    END

    UPDATE dbo.SystemSettings
    SET ReferralCommissionPercent=@Percentage,UpdatedAtUtc=SYSUTCDATETIME(),UpdatedBy=@AdminId
    WHERE Id=1;

    INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
    VALUES(@AdminId,N'Referral.Commission.Update',N'SystemSettings',N'1',N'ReferralCommissionPercent='+CONVERT(nvarchar(30),@Percentage));
END
GO

PRINT 'Referral program upgrade completed successfully.';
GO

/* ===== Compound profit + separate commission wallet final upgrade ===== */
/*
  OLX Trade - Compound Profit + Separate Commission Wallet Upgrade
  Safe to rerun on TahirFxTraderDb after the referral/profit upgrades.

  Rules:
  - Profit base = available InvestmentBalance + available ProfitBalance.
  - CommissionBalance is excluded from profit compounding.
  - Referral commission is credited to CommissionBalance.
  - Welcome bonus remains in ProfitBalance.
  - Withdrawals consume Profit first, then Commission, then Investment.
*/
USE TahirFxTraderDb;
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL OR OBJECT_ID(N'dbo.UserWallets', N'U') IS NULL
BEGIN
    THROW 52001, 'Base user and wallet tables are missing.', 1;
END
GO
IF COL_LENGTH(N'dbo.UserWallets', N'InvestmentBalance') IS NULL OR COL_LENGTH(N'dbo.UserWallets', N'ProfitBalance') IS NULL
BEGIN
    THROW 52002, 'Run ProfitBalanceUpgrade.sql before this script.', 1;
END
GO
IF OBJECT_ID(N'dbo.Referrals', N'U') IS NULL
BEGIN
    THROW 52003, 'Run ReferralProgramUpgrade.sql before this script.', 1;
END
GO
IF OBJECT_ID(N'dbo.ProfitAllocations', N'U') IS NULL
CREATE TABLE dbo.ProfitAllocations
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProfitAllocations PRIMARY KEY,
    ReferenceNo nvarchar(40) NOT NULL CONSTRAINT UQ_ProfitAllocations_Reference UNIQUE,
    UserId bigint NOT NULL,
    InvestmentBase decimal(19,4) NOT NULL,
    ProfitPercentage decimal(9,4) NOT NULL,
    ProfitAmount decimal(19,4) NOT NULL,
    AdminNote nvarchar(500) NULL,
    AddedBy bigint NOT NULL,
    BatchId bigint NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ProfitAllocations_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_ProfitAllocations_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_ProfitAllocations_Admin FOREIGN KEY(AddedBy) REFERENCES dbo.Users(Id)
);
GO
IF OBJECT_ID(N'dbo.ProfitBatches', N'U') IS NULL
CREATE TABLE dbo.ProfitBatches
(
    Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProfitBatches PRIMARY KEY,
    BatchReference nvarchar(40) NOT NULL CONSTRAINT UQ_ProfitBatches_Reference UNIQUE,
    ProfitPercentage decimal(9,4) NOT NULL,
    EligibleUserCount int NOT NULL,
    TotalInvestmentBase decimal(38,4) NOT NULL,
    TotalProfitAmount decimal(38,4) NOT NULL,
    AdminNote nvarchar(500) NULL,
    AddedBy bigint NOT NULL,
    CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ProfitBatches_Created DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT FK_ProfitBatches_Admin FOREIGN KEY(AddedBy) REFERENCES dbo.Users(Id)
);
GO
IF COL_LENGTH(N'dbo.ProfitAllocations',N'BatchId') IS NULL
    ALTER TABLE dbo.ProfitAllocations ADD BatchId bigint NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_ProfitAllocations_Batch' AND parent_object_id=OBJECT_ID(N'dbo.ProfitAllocations'))
    ALTER TABLE dbo.ProfitAllocations ADD CONSTRAINT FK_ProfitAllocations_Batch FOREIGN KEY(BatchId) REFERENCES dbo.ProfitBatches(Id);
GO
IF OBJECT_ID(N'dbo.ProfitReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.ProfitReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.ProfitBatchReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.ProfitBatchReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.WelcomeBonusReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.WelcomeBonusReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.ReferralCommissionReferenceSeq', N'SO') IS NULL CREATE SEQUENCE dbo.ReferralCommissionReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO

IF COL_LENGTH(N'dbo.UserWallets', N'CommissionBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD CommissionBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_Commission DEFAULT(0);
GO
IF COL_LENGTH(N'dbo.UserWallets', N'HeldCommissionBalance') IS NULL
    ALTER TABLE dbo.UserWallets ADD HeldCommissionBalance decimal(19,4) NOT NULL CONSTRAINT DF_Wallet_HeldCommission DEFAULT(0);
GO
IF COL_LENGTH(N'dbo.Withdrawals', N'CommissionAmount') IS NULL
    ALTER TABLE dbo.Withdrawals ADD CommissionAmount decimal(19,4) NOT NULL CONSTRAINT DF_Withdrawals_CommissionAmount DEFAULT(0);
GO
IF COL_LENGTH(N'dbo.WalletLedger', N'CommissionBalanceAfter') IS NULL
    ALTER TABLE dbo.WalletLedger ADD CommissionBalanceAfter decimal(19,4) NOT NULL CONSTRAINT DF_Ledger_CommissionAfter DEFAULT(0);
GO

IF OBJECT_ID(N'dbo.ApplicationMigrations', N'U') IS NULL
CREATE TABLE dbo.ApplicationMigrations
(
    MigrationKey nvarchar(150) NOT NULL CONSTRAINT PK_ApplicationMigrations PRIMARY KEY,
    AppliedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_ApplicationMigrations_Applied DEFAULT(SYSUTCDATETIME())
);
GO

/* Existing historical balances are not reclassified automatically because prior withdrawals
   did not preserve the source of each profit credit. New referral commissions use CommissionBalance. */
IF NOT EXISTS(SELECT 1 FROM dbo.ApplicationMigrations WHERE MigrationKey=N'CompoundProfitCommissionWalletV1')
    INSERT dbo.ApplicationMigrations(MigrationKey) VALUES(N'CompoundProfitCommissionWalletV1');
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetByEmail @Email nvarchar(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,ISNULL(w.CommissionBalance,0) CommissionBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,ISNULL(w.HeldCommissionBalance,0) HeldCommissionBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Email=LOWER(LTRIM(RTRIM(@Email)));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_User_GetById @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,u.PasswordHash,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           u.WithdrawalMinOverride,u.WithdrawalMaxOverride,u.WithdrawalFeePercentOverride,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.HeldBalance,0) HeldBalance,
           ISNULL(w.InvestmentBalance,0) InvestmentBalance,ISNULL(w.ProfitBalance,0) ProfitBalance,ISNULL(w.CommissionBalance,0) CommissionBalance,
           ISNULL(w.HeldInvestmentBalance,0) HeldInvestmentBalance,ISNULL(w.HeldProfitBalance,0) HeldProfitBalance,ISNULL(w.HeldCommissionBalance,0) HeldCommissionBalance,
           u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Users_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id,u.UserTraceId,u.FullName,u.Email,u.Country,u.PhoneNumber,r.Name RoleName,u.Status,u.IsEmailVerified,u.CanDeposit,u.CanWithdraw,
           ISNULL(w.AvailableBalance,0) AvailableBalance,ISNULL(w.InvestmentBalance,0) InvestmentBalance,
           ISNULL(w.ProfitBalance,0) ProfitBalance,ISNULL(w.CommissionBalance,0) CommissionBalance,u.CreatedAtUtc
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id=u.RoleId
    LEFT JOIN dbo.UserWallets w ON w.UserId=u.Id
    ORDER BY u.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalances_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.CommissionBalance,
           w.HeldInvestmentBalance,w.HeldProfitBalance,w.HeldCommissionBalance,
           w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    JOIN dbo.Roles r ON r.Id=u.RoleId
    WHERE r.Name=N'User'
    ORDER BY u.FullName,u.Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserBalance_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Id UserId,u.UserTraceId,u.FullName,u.Email,u.Status,
           w.InvestmentBalance,w.ProfitBalance,w.CommissionBalance,
           w.HeldInvestmentBalance,w.HeldProfitBalance,w.HeldCommissionBalance,
           w.AvailableBalance,w.HeldBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserProfit_Add
    @UserId bigint,
    @Percentage decimal(9,4),
    @Note nvarchar(500)=NULL,
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Percentage<=0 OR @Percentage>100
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Profit percentage must be greater than 0 and not more than 100.' Message,CAST(NULL AS bigint) Id; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Investment decimal(19,4),@ExistingProfit decimal(19,4),@Commission decimal(19,4),@CompoundBase decimal(19,4),
                @ProfitAmount decimal(19,4),@Available decimal(19,4),@ProfitAfter decimal(19,4),@Seq bigint,@Reference nvarchar(40),
                @AllocationId bigint,@UserStatus int;

        SELECT @Investment=w.InvestmentBalance,@ExistingProfit=w.ProfitBalance,@Commission=w.CommissionBalance,@UserStatus=u.Status
        FROM dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.Users u ON u.Id=w.UserId
        WHERE w.UserId=@UserId;

        IF @Investment IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'User wallet was not found.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF @UserStatus<>1 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Profit can only be added to an active user account.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @CompoundBase=@Investment+@ExistingProfit;
        IF @CompoundBase<=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This user has no investment plus profit balance for compounding.' Message,CAST(NULL AS bigint) Id; RETURN; END
        SET @ProfitAmount=ROUND(@CompoundBase*@Percentage/100.0,4);
        IF @ProfitAmount<=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'The calculated profit is too small to credit.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @Seq=NEXT VALUE FOR dbo.ProfitReferenceSeq;
        SET @Reference=N'PFT-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);

        INSERT dbo.ProfitAllocations(ReferenceNo,UserId,InvestmentBase,ProfitPercentage,ProfitAmount,AdminNote,AddedBy)
        VALUES(@Reference,@UserId,@CompoundBase,@Percentage,@ProfitAmount,@Note,@AdminId);
        SET @AllocationId=SCOPE_IDENTITY();

        UPDATE dbo.UserWallets
        SET ProfitBalance=ProfitBalance+@ProfitAmount,AvailableBalance=AvailableBalance+@ProfitAmount,UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId;

        SELECT @Available=AvailableBalance,@Investment=InvestmentBalance,@ProfitAfter=ProfitBalance,@Commission=CommissionBalance
        FROM dbo.UserWallets WHERE UserId=@UserId;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'ProfitCredit',@Reference,N'Compound profit credited at '+CONVERT(nvarchar(30),@Percentage)+N'% on investment + profit',@ProfitAmount,0,@Available,@Investment,@ProfitAfter,@Commission,N'ProfitAllocation',@AllocationId,1);

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'User.Profit.Add',N'ProfitAllocation',CONVERT(nvarchar(60),@AllocationId),
               N'UserId='+CONVERT(nvarchar(30),@UserId)+N'; CompoundBase='+CONVERT(nvarchar(50),@CompoundBase)+N'; Percentage='+CONVERT(nvarchar(30),@Percentage)+N'; Profit='+CONVERT(nvarchar(50),@ProfitAmount));

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Compound profit of $'+CONVERT(nvarchar(50),CAST(@ProfitAmount AS decimal(19,2)))+N' credited on base $'+CONVERT(nvarchar(50),CAST(@CompoundBase AS decimal(19,2)))+N'.' Message,
               @AllocationId Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UserProfit_AddAll
    @Percentage decimal(9,4),
    @Note nvarchar(500)=NULL,
    @AdminId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Percentage<=0 OR @Percentage>100
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Profit percentage must be greater than 0 and not more than 100.' Message,CAST(NULL AS bigint) Id; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        CREATE TABLE #Eligible(UserId bigint NOT NULL PRIMARY KEY,CompoundBase decimal(19,4) NOT NULL,ProfitAmount decimal(19,4) NOT NULL);
        INSERT #Eligible(UserId,CompoundBase,ProfitAmount)
        SELECT u.Id,w.InvestmentBalance+w.ProfitBalance,ROUND((w.InvestmentBalance+w.ProfitBalance)*@Percentage/100.0,4)
        FROM dbo.Users u
        JOIN dbo.Roles r ON r.Id=u.RoleId
        JOIN dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id
        WHERE r.Name=N'User' AND u.Status=1 AND (w.InvestmentBalance+w.ProfitBalance)>0
          AND ROUND((w.InvestmentBalance+w.ProfitBalance)*@Percentage/100.0,4)>0;

        DECLARE @EligibleCount int=(SELECT COUNT(*) FROM #Eligible),
                @TotalBase decimal(38,4)=(SELECT COALESCE(SUM(CONVERT(decimal(38,4),CompoundBase)),0) FROM #Eligible),
                @TotalProfit decimal(38,4)=(SELECT COALESCE(SUM(CONVERT(decimal(38,4),ProfitAmount)),0) FROM #Eligible);
        IF @EligibleCount=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'No active users currently have an investment plus profit balance for compounding.' Message,CAST(NULL AS bigint) Id; RETURN; END

        DECLARE @BatchSeq bigint=NEXT VALUE FOR dbo.ProfitBatchReferenceSeq,@BatchReference nvarchar(40),@BatchId bigint;
        SET @BatchReference=N'PFB-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@BatchSeq),6);
        INSERT dbo.ProfitBatches(BatchReference,ProfitPercentage,EligibleUserCount,TotalInvestmentBase,TotalProfitAmount,AdminNote,AddedBy)
        VALUES(@BatchReference,@Percentage,@EligibleCount,@TotalBase,@TotalProfit,@Note,@AdminId);
        SET @BatchId=SCOPE_IDENTITY();

        DECLARE @Allocated TABLE(AllocationId bigint,UserId bigint,ReferenceNo nvarchar(40),CompoundBase decimal(19,4),ProfitAmount decimal(19,4));
        INSERT dbo.ProfitAllocations(ReferenceNo,UserId,InvestmentBase,ProfitPercentage,ProfitAmount,AdminNote,AddedBy,BatchId)
        OUTPUT inserted.Id,inserted.UserId,inserted.ReferenceNo,inserted.InvestmentBase,inserted.ProfitAmount
        INTO @Allocated(AllocationId,UserId,ReferenceNo,CompoundBase,ProfitAmount)
        SELECT N'PFT-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),NEXT VALUE FOR dbo.ProfitReferenceSeq),6),
               e.UserId,e.CompoundBase,@Percentage,e.ProfitAmount,@Note,@AdminId,@BatchId
        FROM #Eligible e;

        UPDATE w SET ProfitBalance=ProfitBalance+e.ProfitAmount,AvailableBalance=AvailableBalance+e.ProfitAmount,UpdatedAtUtc=SYSUTCDATETIME()
        FROM dbo.UserWallets w JOIN #Eligible e ON e.UserId=w.UserId;

        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        SELECT a.UserId,N'ProfitCredit',a.ReferenceNo,
               N'Bulk compound profit at '+CONVERT(nvarchar(30),@Percentage)+N'% (batch '+@BatchReference+N')',
               a.ProfitAmount,0,w.AvailableBalance,w.InvestmentBalance,w.ProfitBalance,w.CommissionBalance,N'ProfitAllocation',a.AllocationId,1
        FROM @Allocated a JOIN dbo.UserWallets w ON w.UserId=a.UserId;

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details)
        VALUES(@AdminId,N'User.Profit.AddAll',N'ProfitBatch',CONVERT(nvarchar(60),@BatchId),
               N'Batch='+@BatchReference+N'; EligibleUsers='+CONVERT(nvarchar(20),@EligibleCount)+N'; CompoundBase='+CONVERT(nvarchar(60),@TotalBase)+N'; Percentage='+CONVERT(nvarchar(30),@Percentage)+N'; TotalProfit='+CONVERT(nvarchar(60),@TotalProfit));

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,
               N'Bulk compound profit batch '+@BatchReference+N' completed. '+CONVERT(nvarchar(20),@EligibleCount)+N' users received $'+CONVERT(nvarchar(60),CAST(@TotalProfit AS decimal(38,2)))+N' total profit on $'+CONVERT(nvarchar(60),CAST(@TotalBase AS decimal(38,2)))+N' combined investment and profit.' Message,
               @BatchId Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawal_Create
    @UserId bigint,@PaymentMethodId int,@Amount decimal(19,4),@DestinationJson nvarchar(max),@DestinationDisplay nvarchar(300)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF ISJSON(@DestinationJson)<>1 BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal destination is invalid.' Message,CAST(NULL AS bigint) Id; RETURN; END
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Can bit,@UserStatus int,@Verified bit,@UserMin decimal(19,4),@UserMax decimal(19,4),@UserFee decimal(9,4),
                @Available decimal(19,4),@Investment decimal(19,4),@Profit decimal(19,4),@Commission decimal(19,4),
                @GlobalMin decimal(19,4),@GlobalMax decimal(19,4),@GlobalFee decimal(9,4),@MethodMin decimal(19,4),@MethodMax decimal(19,4),
                @MethodFee decimal(9,4),@MethodActive bit,@Supports bit,@EffectiveMin decimal(19,4),@EffectiveMax decimal(19,4),@FeePct decimal(9,4),
                @ProfitUsed decimal(19,4),@CommissionUsed decimal(19,4),@InvestmentUsed decimal(19,4),@Remaining decimal(19,4);

        SELECT @Can=u.CanWithdraw,@UserStatus=u.Status,@Verified=u.IsEmailVerified,@UserMin=u.WithdrawalMinOverride,@UserMax=u.WithdrawalMaxOverride,@UserFee=u.WithdrawalFeePercentOverride,
               @Available=w.AvailableBalance,@Investment=w.InvestmentBalance,@Profit=w.ProfitBalance,@Commission=w.CommissionBalance
        FROM dbo.Users u JOIN dbo.UserWallets w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id WHERE u.Id=@UserId;
        SELECT @GlobalMin=DefaultWithdrawalMin,@GlobalMax=DefaultWithdrawalMax,@GlobalFee=DefaultWithdrawalFeePercent FROM dbo.SystemSettings WHERE Id=1;
        SELECT @MethodMin=MinWithdrawal,@MethodMax=MaxWithdrawal,@MethodFee=WithdrawalFeePercent,@MethodActive=IsActive,@Supports=SupportsWithdrawal FROM dbo.PaymentMethods WHERE Id=@PaymentMethodId;

        IF ISNULL(@UserStatus,-1)<>1 OR ISNULL(@Verified,0)<>1 OR ISNULL(@Can,0)<>1 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawals are disabled for this account.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF ISNULL(@MethodActive,0)<>1 OR ISNULL(@Supports,0)<>1 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'The selected withdrawal method is unavailable.' Message,CAST(NULL AS bigint) Id; RETURN; END
        SET @EffectiveMin=CASE WHEN ISNULL(@UserMin,@GlobalMin)>@MethodMin THEN ISNULL(@UserMin,@GlobalMin) ELSE @MethodMin END;
        SET @EffectiveMax=ISNULL(@UserMax,@GlobalMax); IF @MethodMax IS NOT NULL AND @MethodMax<@EffectiveMax SET @EffectiveMax=@MethodMax;
        SET @FeePct=COALESCE(@UserFee,NULLIF(@MethodFee,0),@GlobalFee);
        IF @Amount<@EffectiveMin OR @Amount>@EffectiveMax BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,CAST(NULL AS bigint) Id; RETURN; END
        IF @Available<@Amount OR (@Investment+@Profit+@Commission)<@Amount BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Insufficient available balance.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SET @ProfitUsed=CASE WHEN @Profit>=@Amount THEN @Amount ELSE @Profit END;
        SET @Remaining=@Amount-@ProfitUsed;
        SET @CommissionUsed=CASE WHEN @Commission>=@Remaining THEN @Remaining ELSE @Commission END;
        SET @InvestmentUsed=@Remaining-@CommissionUsed;

        DECLARE @Fee decimal(19,4)=ROUND(@Amount*@FeePct/100.0,4),@Net decimal(19,4)=@Amount-ROUND(@Amount*@FeePct/100.0,4),
                @Seq bigint=NEXT VALUE FOR dbo.WithdrawalReferenceSeq,@Ref nvarchar(40),@Balance decimal(19,4),@InvestmentAfter decimal(19,4),
                @ProfitAfter decimal(19,4),@CommissionAfter decimal(19,4);
        IF @Net<=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount must be greater than the fee.' Message,CAST(NULL AS bigint) Id; RETURN; END
        SET @Ref=N'WDL-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Seq),6);

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance-@Amount,HeldBalance=HeldBalance+@Amount,
            ProfitBalance=ProfitBalance-@ProfitUsed,CommissionBalance=CommissionBalance-@CommissionUsed,InvestmentBalance=InvestmentBalance-@InvestmentUsed,
            HeldProfitBalance=HeldProfitBalance+@ProfitUsed,HeldCommissionBalance=HeldCommissionBalance+@CommissionUsed,HeldInvestmentBalance=HeldInvestmentBalance+@InvestmentUsed,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId AND AvailableBalance>=@Amount AND ProfitBalance>=@ProfitUsed AND CommissionBalance>=@CommissionUsed AND InvestmentBalance>=@InvestmentUsed;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Wallet balances changed while the request was being processed. Please try again.' Message,CAST(NULL AS bigint) Id; RETURN; END

        SELECT @Balance=AvailableBalance,@InvestmentAfter=InvestmentBalance,@ProfitAfter=ProfitBalance,@CommissionAfter=CommissionBalance FROM dbo.UserWallets WHERE UserId=@UserId;
        INSERT dbo.Withdrawals(ReferenceNo,UserId,PaymentMethodId,Amount,FeePercent,FeeAmount,NetAmount,ProfitAmount,CommissionAmount,InvestmentAmount,DestinationJson,DestinationDisplay,Status)
        VALUES(@Ref,@UserId,@PaymentMethodId,@Amount,@FeePct,@Fee,@Net,@ProfitUsed,@CommissionUsed,@InvestmentUsed,@DestinationJson,@DestinationDisplay,0);
        DECLARE @Id bigint=SCOPE_IDENTITY();
        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'WithdrawalDebit',@Ref,N'Withdrawal reserved: profit first, commission second, investment last',0,@Amount,@Balance,@InvestmentAfter,@ProfitAfter,@CommissionAfter,N'Withdrawal',@Id,0);

        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal submitted. $'+CONVERT(nvarchar(50),CAST(@ProfitUsed AS decimal(19,2)))+N' reserved from profit, $'+CONVERT(nvarchar(50),CAST(@CommissionUsed AS decimal(19,2)))+N' from commission, and $'+CONVERT(nvarchar(50),CAST(@InvestmentUsed AS decimal(19,2)))+N' from investment.' Message,@Id Id;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Complete @Id bigint,@AdminId bigint,@PaymentReference nvarchar(150),@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@PaymentReference)),N'') IS NULL BEGIN SELECT CAST(0 AS bit) Succeeded,N'Payment reference is required to complete a withdrawal.' Message,@Id Id; RETURN; END
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@FeeAmount decimal(19,4),@ProfitAmount decimal(19,4),@CommissionAmount decimal(19,4),@InvestmentAmount decimal(19,4),@Ref nvarchar(40),@CompanyBalance decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@FeeAmount=FeeAmount,@ProfitAmount=ProfitAmount,@CommissionAmount=CommissionAmount,@InvestmentAmount=InvestmentAmount,@Ref=ReferenceNo
        FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
        IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET HeldBalance=HeldBalance-@Amount,HeldProfitBalance=HeldProfitBalance-@ProfitAmount,HeldCommissionBalance=HeldCommissionBalance-@CommissionAmount,HeldInvestmentBalance=HeldInvestmentBalance-@InvestmentAmount,UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId AND HeldBalance>=@Amount AND HeldProfitBalance>=@ProfitAmount AND HeldCommissionBalance>=@CommissionAmount AND HeldInvestmentBalance>=@InvestmentAmount;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END

        UPDATE dbo.Withdrawals SET Status=3,AdminNote=@AdminNote,AdminPaymentReference=@PaymentReference,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        UPDATE dbo.WalletLedger SET IsVisible=1,Description=N'Completed withdrawal: profit $'+CONVERT(nvarchar(50),CAST(@ProfitAmount AS decimal(19,2)))+N', commission $'+CONVERT(nvarchar(50),CAST(@CommissionAmount AS decimal(19,2)))+N', investment $'+CONVERT(nvarchar(50),CAST(@InvestmentAmount AS decimal(19,2))) WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id;

        UPDATE dbo.CompanyWallets SET Balance=Balance-@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId) VALUES(N'WithdrawalSettlement',@Ref,N'Withdrawal settled to user',0,@Amount,@CompanyBalance,N'Withdrawal',@Id);
        IF @FeeAmount>0
        BEGIN
            UPDATE dbo.CompanyWallets SET Balance=Balance+@FeeAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
            SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
            INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId) VALUES(N'WithdrawalFee',@Ref,N'Withdrawal fee transferred to company wallet',@FeeAmount,0,@CompanyBalance,N'WithdrawalFee',@Id);
        END
        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Withdrawal.Complete',N'Withdrawal',CONVERT(nvarchar(60),@Id),@PaymentReference);
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal completed using profit, commission, then investment. Fee was credited to the company wallet.' Message,@Id Id;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_Reject @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Amount decimal(19,4),@ProfitAmount decimal(19,4),@CommissionAmount decimal(19,4),@InvestmentAmount decimal(19,4);
        SELECT @Status=Status,@UserId=UserId,@Amount=Amount,@ProfitAmount=ProfitAmount,@CommissionAmount=CommissionAmount,@InvestmentAmount=InvestmentAmount FROM dbo.Withdrawals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal not found.' Message,@Id Id; RETURN; END
        IF @Status NOT IN(0,1) BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal is already finalized.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets
        SET AvailableBalance=AvailableBalance+@Amount,HeldBalance=HeldBalance-@Amount,
            ProfitBalance=ProfitBalance+@ProfitAmount,CommissionBalance=CommissionBalance+@CommissionAmount,InvestmentBalance=InvestmentBalance+@InvestmentAmount,
            HeldProfitBalance=HeldProfitBalance-@ProfitAmount,HeldCommissionBalance=HeldCommissionBalance-@CommissionAmount,HeldInvestmentBalance=HeldInvestmentBalance-@InvestmentAmount,
            UpdatedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId AND HeldBalance>=@Amount AND HeldProfitBalance>=@ProfitAmount AND HeldCommissionBalance>=@CommissionAmount AND HeldInvestmentBalance>=@InvestmentAmount;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Held wallet balance is inconsistent. No changes were made.' Message,@Id Id; RETURN; END

        UPDATE dbo.Withdrawals SET Status=4,AdminNote=@AdminNote,ReviewedBy=@AdminId,CompletedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        DELETE dbo.WalletLedger WHERE RelatedEntityType=N'Withdrawal' AND RelatedEntityId=@Id AND IsVisible=0;
        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Withdrawal.Reject',N'Withdrawal',CONVERT(nvarchar(60),@Id),@AdminNote);
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal rejected and the original profit, commission, and investment split was restored.' Message,@Id Id;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.UserId=@UserId ORDER BY w.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    ORDER BY CASE WHEN w.Status IN(0,1) THEN 0 ELSE 1 END,w.CreatedAtUtc DESC;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,w.PaymentMethodId,p.Name PaymentMethodName,
           w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,w.DestinationJson,w.DestinationDisplay,
           w.Status,w.AdminNote,w.AdminPaymentReference,w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w JOIN dbo.Users u ON u.Id=w.UserId JOIN dbo.PaymentMethods p ON p.Id=w.PaymentMethodId
    WHERE w.Id=@Id;
END
GO

/* First approved deposit: investment + welcome profit + referral commission wallet. */
CREATE OR ALTER PROCEDURE dbo.sp_Admin_Deposit_Approve @Id bigint,@AdminId bigint,@AdminNote nvarchar(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Status int,@UserId bigint,@Net decimal(19,4),@Ref nvarchar(40),@Amount decimal(19,4),@UserBalance decimal(19,4),
                @InvestmentBalance decimal(19,4),@ProfitBalance decimal(19,4),@CommissionBalance decimal(19,4),@CompanyBalance decimal(19,4),@IsFirstApprovedDeposit bit=0;
        SELECT @Status=Status,@UserId=UserId,@Net=NetAmount,@Ref=ReferenceNo,@Amount=Amount FROM dbo.Deposits WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id;
        IF @Status IS NULL BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Deposit not found.' Message,@Id Id; RETURN; END
        IF @Status<>0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This deposit has already been reviewed.' Message,@Id Id; RETURN; END

        UPDATE dbo.UserWallets SET AvailableBalance=AvailableBalance+@Net,InvestmentBalance=InvestmentBalance+@Net,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'User wallet was not found.' Message,@Id Id; RETURN; END
        SET @IsFirstApprovedDeposit=CASE WHEN EXISTS(SELECT 1 FROM dbo.Deposits WHERE UserId=@UserId AND Status=2) THEN 0 ELSE 1 END;
        SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance,@CommissionBalance=CommissionBalance FROM dbo.UserWallets WHERE UserId=@UserId;
        UPDATE dbo.Deposits SET Status=2,AdminNote=@AdminNote,ReviewedBy=@AdminId,ReviewedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
        VALUES(@UserId,N'DepositCredit',@Ref,N'Approved deposit added to investment wallet',@Net,0,@UserBalance,@InvestmentBalance,@ProfitBalance,@CommissionBalance,N'Deposit',@Id,1);

        UPDATE dbo.CompanyWallets SET Balance=Balance+@Amount,UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=1;
        SELECT @CompanyBalance=Balance FROM dbo.CompanyWallets WHERE Id=1;
        INSERT dbo.CompanyLedger(EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,RelatedEntityType,RelatedEntityId) VALUES(N'DepositReceipt',@Ref,N'Deposit received from user',@Amount,0,@CompanyBalance,N'Deposit',@Id);

        IF @IsFirstApprovedDeposit=1
        BEGIN
            DECLARE @WelcomePercent decimal(9,4)=0,@ReferralPercent decimal(9,4)=0,@WelcomeAmount decimal(19,4)=0,@ReferralAmount decimal(19,4)=0,
                    @WelcomeReference nvarchar(40)=NULL,@ReferralReference nvarchar(40)=NULL,@WelcomeBonusId bigint=NULL,@ReferralId bigint=NULL,@ReferrerUserId bigint=NULL,
                    @ReferrerBalance decimal(19,4),@ReferrerInvestment decimal(19,4),@ReferrerProfit decimal(19,4),@ReferrerCommission decimal(19,4),@Sequence bigint;
            SELECT @WelcomePercent=WelcomeBonusPercent,@ReferralPercent=ReferralCommissionPercent FROM dbo.SystemSettings WITH(HOLDLOCK) WHERE Id=1;
            SET @WelcomeAmount=ROUND(@Amount*@WelcomePercent/100.0,4);
            IF @WelcomeAmount>0
            BEGIN
                SET @Sequence=NEXT VALUE FOR dbo.WelcomeBonusReferenceSeq;
                SET @WelcomeReference=N'WLB-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Sequence),6);
                INSERT dbo.WelcomeBonuses(ReferenceNo,UserId,DepositId,DepositAmount,BonusPercent,BonusAmount) VALUES(@WelcomeReference,@UserId,@Id,@Amount,@WelcomePercent,@WelcomeAmount);
                SET @WelcomeBonusId=SCOPE_IDENTITY();
                UPDATE dbo.UserWallets SET ProfitBalance=ProfitBalance+@WelcomeAmount,AvailableBalance=AvailableBalance+@WelcomeAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@UserId;
                SELECT @UserBalance=AvailableBalance,@InvestmentBalance=InvestmentBalance,@ProfitBalance=ProfitBalance,@CommissionBalance=CommissionBalance FROM dbo.UserWallets WHERE UserId=@UserId;
                INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
                VALUES(@UserId,N'WelcomeBonus',@WelcomeReference,N'Welcome bonus credited to profit wallet',@WelcomeAmount,0,@UserBalance,@InvestmentBalance,@ProfitBalance,@CommissionBalance,N'WelcomeBonus',@WelcomeBonusId,1);
            END

            SELECT @ReferralId=Id,@ReferrerUserId=ReferrerUserId FROM dbo.Referrals WITH(UPDLOCK,HOLDLOCK) WHERE ReferredUserId=@UserId AND IsQualified=0;
            IF @ReferralId IS NOT NULL
            BEGIN
                SET @ReferralAmount=ROUND(@Amount*@ReferralPercent/100.0,4);
                IF @ReferralAmount>0
                BEGIN
                    SET @Sequence=NEXT VALUE FOR dbo.ReferralCommissionReferenceSeq;
                    SET @ReferralReference=N'RFC-'+CONVERT(char(8),SYSUTCDATETIME(),112)+N'-'+RIGHT(N'000000'+CONVERT(nvarchar(20),@Sequence),6);
                    UPDATE dbo.UserWallets SET CommissionBalance=CommissionBalance+@ReferralAmount,AvailableBalance=AvailableBalance+@ReferralAmount,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@ReferrerUserId;
                    IF @@ROWCOUNT=0 BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Referrer wallet was not found. No deposit changes were committed.' Message,@Id Id; RETURN; END
                    SELECT @ReferrerBalance=AvailableBalance,@ReferrerInvestment=InvestmentBalance,@ReferrerProfit=ProfitBalance,@ReferrerCommission=CommissionBalance FROM dbo.UserWallets WHERE UserId=@ReferrerUserId;
                    INSERT dbo.WalletLedger(UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,RelatedEntityType,RelatedEntityId,IsVisible)
                    VALUES(@ReferrerUserId,N'ReferralCommission',@ReferralReference,N'Referral commission credited to commission wallet',@ReferralAmount,0,@ReferrerBalance,@ReferrerInvestment,@ReferrerProfit,@ReferrerCommission,N'Referral',@ReferralId,1);
                END
                UPDATE dbo.Referrals SET IsQualified=1,FirstDepositId=@Id,FirstDepositAmount=@Amount,WelcomeBonusPercent=@WelcomePercent,WelcomeBonusAmount=@WelcomeAmount,WelcomeBonusReferenceNo=@WelcomeReference,
                       ReferralCommissionPercent=@ReferralPercent,ReferralCommissionAmount=@ReferralAmount,ReferralCommissionReferenceNo=@ReferralReference,QualifiedAtUtc=SYSUTCDATETIME()
                WHERE Id=@ReferralId;
            END
        END

        INSERT dbo.AuditLogs(UserId,ActionName,EntityType,EntityId,Details) VALUES(@AdminId,N'Deposit.Approve',N'Deposit',CONVERT(nvarchar(60),@Id),COALESCE(@AdminNote,N'')+CASE WHEN @IsFirstApprovedDeposit=1 THEN N'; First deposit rewards evaluated.' ELSE N'' END);
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Deposit approved and added to investment wallet.'+CASE WHEN @IsFirstApprovedDeposit=1 THEN N' Welcome bonus went to profit wallet and referral commission went to commission wallet.' ELSE N'' END Message,@Id Id;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id; END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.FullName,u.UserTraceId,w.AvailableBalance,w.HeldBalance,w.InvestmentBalance,w.ProfitBalance,w.CommissionBalance,
           w.HeldInvestmentBalance,w.HeldProfitBalance,w.HeldCommissionBalance,
           ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
           ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
           (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
           (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals,
           (SELECT COUNT(*) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1) SuccessfulReferralCount,
           ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1),0) ReferralCommissionEarned
    FROM dbo.Users u JOIN dbo.UserWallets w ON w.UserId=u.Id WHERE u.Id=@UserId;

    SELECT TOP(10) Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger WHERE UserId=@UserId AND IsVisible=1 ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Ledger_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger WHERE UserId=@UserId AND IsVisible=1 ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

PRINT 'Compound profit and separate commission wallet upgrade completed.';
GO


/* Dashboard portfolio refresh */
USE TahirFxTraderDb;
GO

/* Dashboard portfolio refresh: adds Today's PnL to the dashboard result. */
CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayStartUtc datetime2(0) = CONVERT(date, SYSUTCDATETIME());
    DECLARE @OpeningProfitBalance decimal(19,4);

    SELECT TOP(1) @OpeningProfitBalance = ProfitBalanceAfter
    FROM dbo.WalletLedger
    WHERE UserId = @UserId
      AND IsVisible = 1
      AND CreatedAtUtc < @TodayStartUtc
    ORDER BY CreatedAtUtc DESC, Id DESC;

    SELECT
        u.FullName,
        u.UserTraceId,
        w.AvailableBalance,
        w.HeldBalance,
        w.InvestmentBalance,
        w.ProfitBalance,
        w.CommissionBalance,
        w.HeldInvestmentBalance,
        w.HeldProfitBalance,
        w.HeldCommissionBalance,
        ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
        ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
        (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
        (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals,
        (SELECT COUNT(*) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1) SuccessfulReferralCount,
        ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1),0) ReferralCommissionEarned,
        CAST(w.ProfitBalance - ISNULL(@OpeningProfitBalance, 0) AS decimal(19,4)) TodayPnl
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;

    SELECT TOP(10)
        Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,
        InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId=@UserId AND IsVisible=1
    ORDER BY CreatedAtUtc DESC,Id DESC;
END
GO

PRINT 'Dashboard portfolio and Today PnL upgrade completed.';
GO
/*
  OLX Trade - Wallet Source Withdrawal Upgrade
  Adds source selection: Investment OR Profit + Commission.
  Investment withdrawals use the admin-controlled investment fee.
  Profit + Commission withdrawals have zero fee.
  Safe to rerun on TahirFxTraderDb.
*/
USE TahirFxTraderDb;
GO

IF COL_LENGTH(N'dbo.Withdrawals', N'WalletSource') IS NULL
BEGIN
    ALTER TABLE dbo.Withdrawals
    ADD WalletSource nvarchar(30) NOT NULL
        CONSTRAINT DF_Withdrawals_WalletSource DEFAULT(N'MixedLegacy');
END
GO

/* Classify older records where the original wallet split is unambiguous. */
UPDATE dbo.Withdrawals
SET WalletSource = CASE
    WHEN InvestmentAmount > 0 AND ISNULL(ProfitAmount,0) = 0 AND ISNULL(CommissionAmount,0) = 0 THEN N'Investment'
    WHEN ISNULL(InvestmentAmount,0) = 0 AND (ISNULL(ProfitAmount,0) > 0 OR ISNULL(CommissionAmount,0) > 0) THEN N'ProfitCommission'
    ELSE N'MixedLegacy'
END
WHERE WalletSource IS NULL OR WalletSource = N'MixedLegacy';
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawal_Create
    @UserId bigint,
    @PaymentMethodId int,
    @WalletSource nvarchar(30),
    @Amount decimal(19,4),
    @DestinationJson nvarchar(max),
    @DestinationDisplay nvarchar(300)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @WalletSource = LTRIM(RTRIM(@WalletSource));

    IF @WalletSource NOT IN (N'Investment', N'ProfitCommission')
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,
               N'Select Investment Wallet or Profit + Commission wallet.' Message,
               CAST(NULL AS bigint) Id;
        RETURN;
    END

    IF ISJSON(@DestinationJson) <> 1
    BEGIN
        SELECT CAST(0 AS bit) Succeeded,
               N'Withdrawal destination is invalid.' Message,
               CAST(NULL AS bigint) Id;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        DECLARE
            @Can bit,
            @UserStatus int,
            @Verified bit,
            @UserMin decimal(19,4),
            @UserMax decimal(19,4),
            @UserInvestmentFee decimal(9,4),
            @Available decimal(19,4),
            @Investment decimal(19,4),
            @Profit decimal(19,4),
            @Commission decimal(19,4),
            @GlobalMin decimal(19,4),
            @GlobalMax decimal(19,4),
            @GlobalInvestmentFee decimal(9,4),
            @MethodMin decimal(19,4),
            @MethodMax decimal(19,4),
            @MethodActive bit,
            @Supports bit,
            @EffectiveMin decimal(19,4),
            @EffectiveMax decimal(19,4),
            @FeePct decimal(9,4),
            @SourceAvailable decimal(19,4),
            @ProfitUsed decimal(19,4) = 0,
            @CommissionUsed decimal(19,4) = 0,
            @InvestmentUsed decimal(19,4) = 0,
            @Remaining decimal(19,4) = 0;

        SELECT
            @Can = u.CanWithdraw,
            @UserStatus = u.Status,
            @Verified = u.IsEmailVerified,
            @UserMin = u.WithdrawalMinOverride,
            @UserMax = u.WithdrawalMaxOverride,
            @UserInvestmentFee = u.WithdrawalFeePercentOverride,
            @Available = w.AvailableBalance,
            @Investment = w.InvestmentBalance,
            @Profit = w.ProfitBalance,
            @Commission = w.CommissionBalance
        FROM dbo.Users u
        JOIN dbo.UserWallets w WITH (UPDLOCK, HOLDLOCK) ON w.UserId = u.Id
        WHERE u.Id = @UserId;

        SELECT
            @GlobalMin = DefaultWithdrawalMin,
            @GlobalMax = DefaultWithdrawalMax,
            @GlobalInvestmentFee = DefaultWithdrawalFeePercent
        FROM dbo.SystemSettings
        WHERE Id = 1;

        SELECT
            @MethodMin = MinWithdrawal,
            @MethodMax = MaxWithdrawal,
            @MethodActive = IsActive,
            @Supports = SupportsWithdrawal
        FROM dbo.PaymentMethods
        WHERE Id = @PaymentMethodId;

        IF ISNULL(@UserStatus, -1) <> 1 OR ISNULL(@Verified, 0) <> 1 OR ISNULL(@Can, 0) <> 1
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'Withdrawals are disabled for this account.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        IF ISNULL(@MethodActive, 0) <> 1 OR ISNULL(@Supports, 0) <> 1
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'The selected withdrawal method is unavailable.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        SET @EffectiveMin = CASE
            WHEN ISNULL(@UserMin, @GlobalMin) > ISNULL(@MethodMin, 0)
                THEN ISNULL(@UserMin, @GlobalMin)
            ELSE ISNULL(@MethodMin, 0)
        END;

        SET @EffectiveMax = ISNULL(@UserMax, @GlobalMax);
        IF @MethodMax IS NOT NULL AND @MethodMax < @EffectiveMax
            SET @EffectiveMax = @MethodMax;

        IF @Amount < @EffectiveMin OR @Amount > @EffectiveMax
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        IF @WalletSource = N'Investment'
        BEGIN
            SET @SourceAvailable = ISNULL(@Investment, 0);
            SET @InvestmentUsed = @Amount;
            SET @FeePct = COALESCE(@UserInvestmentFee, @GlobalInvestmentFee, 0);
        END
        ELSE
        BEGIN
            SET @SourceAvailable = ISNULL(@Profit, 0) + ISNULL(@Commission, 0);
            SET @ProfitUsed = CASE WHEN ISNULL(@Profit,0) >= @Amount THEN @Amount ELSE ISNULL(@Profit,0) END;
            SET @Remaining = @Amount - @ProfitUsed;
            SET @CommissionUsed = @Remaining;
            SET @FeePct = 0;
        END

        IF @Amount <= 0 OR @SourceAvailable < @Amount OR ISNULL(@Available,0) < @Amount
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   CASE WHEN @WalletSource = N'Investment'
                        THEN N'Insufficient Investment Wallet balance.'
                        ELSE N'Insufficient combined Profit and Commission balance.' END Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        DECLARE
            @Fee decimal(19,4) = ROUND(@Amount * @FeePct / 100.0, 4),
            @Net decimal(19,4),
            @Seq bigint = NEXT VALUE FOR dbo.WithdrawalReferenceSeq,
            @Ref nvarchar(40),
            @Balance decimal(19,4),
            @InvestmentAfter decimal(19,4),
            @ProfitAfter decimal(19,4),
            @CommissionAfter decimal(19,4);

        SET @Net = @Amount - @Fee;
        IF @Net <= 0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'Withdrawal amount must be greater than the investment withdrawal fee.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        SET @Ref = N'WDL-' + CONVERT(char(8), SYSUTCDATETIME(), 112)
                 + N'-' + RIGHT(N'000000' + CONVERT(nvarchar(20), @Seq), 6);

        UPDATE dbo.UserWallets
        SET
            AvailableBalance = AvailableBalance - @Amount,
            HeldBalance = HeldBalance + @Amount,
            InvestmentBalance = InvestmentBalance - @InvestmentUsed,
            ProfitBalance = ProfitBalance - @ProfitUsed,
            CommissionBalance = CommissionBalance - @CommissionUsed,
            HeldInvestmentBalance = HeldInvestmentBalance + @InvestmentUsed,
            HeldProfitBalance = HeldProfitBalance + @ProfitUsed,
            HeldCommissionBalance = HeldCommissionBalance + @CommissionUsed,
            UpdatedAtUtc = SYSUTCDATETIME()
        WHERE UserId = @UserId
          AND AvailableBalance >= @Amount
          AND InvestmentBalance >= @InvestmentUsed
          AND ProfitBalance >= @ProfitUsed
          AND CommissionBalance >= @CommissionUsed;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK;
            SELECT CAST(0 AS bit) Succeeded,
                   N'Wallet balances changed while the request was being processed. Please try again.' Message,
                   CAST(NULL AS bigint) Id;
            RETURN;
        END

        SELECT
            @Balance = AvailableBalance,
            @InvestmentAfter = InvestmentBalance,
            @ProfitAfter = ProfitBalance,
            @CommissionAfter = CommissionBalance
        FROM dbo.UserWallets
        WHERE UserId = @UserId;

        INSERT dbo.Withdrawals
        (
            ReferenceNo, UserId, PaymentMethodId, WalletSource,
            Amount, FeePercent, FeeAmount, NetAmount,
            ProfitAmount, CommissionAmount, InvestmentAmount,
            DestinationJson, DestinationDisplay, Status
        )
        VALUES
        (
            @Ref, @UserId, @PaymentMethodId, @WalletSource,
            @Amount, @FeePct, @Fee, @Net,
            @ProfitUsed, @CommissionUsed, @InvestmentUsed,
            @DestinationJson, @DestinationDisplay, 0
        );

        DECLARE @Id bigint = SCOPE_IDENTITY();

        INSERT dbo.WalletLedger
        (
            UserId, EntryType, ReferenceNo, Description,
            Credit, Debit, BalanceAfter,
            InvestmentBalanceAfter, ProfitBalanceAfter, CommissionBalanceAfter,
            RelatedEntityType, RelatedEntityId, IsVisible
        )
        VALUES
        (
            @UserId, N'WithdrawalDebit', @Ref,
            CASE WHEN @WalletSource = N'Investment'
                 THEN N'Investment Wallet withdrawal reserved'
                 ELSE N'Profit + Commission withdrawal reserved (profit first)' END,
            0, @Amount, @Balance,
            @InvestmentAfter, @ProfitAfter, @CommissionAfter,
            N'Withdrawal', @Id, 0
        );

        COMMIT;

        SELECT CAST(1 AS bit) Succeeded,
               CASE WHEN @WalletSource = N'Investment'
                    THEN N'Investment withdrawal submitted. Fee: '
                       + CONVERT(nvarchar(30), CAST(@FeePct AS decimal(9,2))) + N'%. Amount to receive: $'
                       + CONVERT(nvarchar(50), CAST(@Net AS decimal(19,2))) + N'.'
                    ELSE N'Profit + Commission withdrawal submitted with 0% fee. $'
                       + CONVERT(nvarchar(50), CAST(@ProfitUsed AS decimal(19,2))) + N' reserved from Profit and $'
                       + CONVERT(nvarchar(50), CAST(@CommissionUsed AS decimal(19,2))) + N' from Commission.' END Message,
               @Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,
               ERROR_MESSAGE() Message,
               CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Withdrawals_GetByUser @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,
        w.PaymentMethodId,p.Name PaymentMethodName,w.WalletSource,
        w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,
        w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,
        w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,
        w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id = w.UserId
    JOIN dbo.PaymentMethods p ON p.Id = w.PaymentMethodId
    WHERE w.UserId = @UserId
    ORDER BY w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawals_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,
        w.PaymentMethodId,p.Name PaymentMethodName,w.WalletSource,
        w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,
        w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,
        w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,
        w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id = w.UserId
    JOIN dbo.PaymentMethods p ON p.Id = w.PaymentMethodId
    ORDER BY CASE WHEN w.Status IN (0,1) THEN 0 ELSE 1 END, w.CreatedAtUtc DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_Withdrawal_GetById @Id bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        w.Id,w.ReferenceNo,w.UserId,u.UserTraceId,u.FullName UserName,u.Email UserEmail,
        w.PaymentMethodId,p.Name PaymentMethodName,w.WalletSource,
        w.Amount,w.FeePercent,w.FeeAmount,w.NetAmount,
        w.ProfitAmount,w.CommissionAmount,w.InvestmentAmount,
        w.DestinationJson,w.DestinationDisplay,w.Status,w.AdminNote,w.AdminPaymentReference,
        w.CreatedAtUtc,w.CompletedAtUtc
    FROM dbo.Withdrawals w
    JOIN dbo.Users u ON u.Id = w.UserId
    JOIN dbo.PaymentMethods p ON p.Id = w.PaymentMethodId
    WHERE w.Id = @Id;
END
GO

/* Include the effective investment-withdrawal fee in the dashboard result. */
CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayStartUtc datetime2(0) = CONVERT(date, SYSUTCDATETIME());
    DECLARE @OpeningProfitBalance decimal(19,4);

    SELECT TOP(1) @OpeningProfitBalance = ProfitBalanceAfter
    FROM dbo.WalletLedger
    WHERE UserId = @UserId
      AND IsVisible = 1
      AND CreatedAtUtc < @TodayStartUtc
    ORDER BY CreatedAtUtc DESC, Id DESC;

    SELECT
        u.FullName,
        u.UserTraceId,
        w.AvailableBalance,
        w.HeldBalance,
        w.InvestmentBalance,
        w.ProfitBalance,
        w.CommissionBalance,
        w.HeldInvestmentBalance,
        w.HeldProfitBalance,
        w.HeldCommissionBalance,
        ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
        ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
        (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
        (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals,
        (SELECT COUNT(*) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1) SuccessfulReferralCount,
        ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1),0) ReferralCommissionEarned,
        CAST(w.ProfitBalance - ISNULL(@OpeningProfitBalance, 0) AS decimal(19,4)) TodayPnl,
        CAST(COALESCE(u.WithdrawalFeePercentOverride, s.DefaultWithdrawalFeePercent, 0) AS decimal(9,4)) InvestmentWithdrawalFeePercent
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId = u.Id
    JOIN dbo.SystemSettings s ON s.Id = 1
    WHERE u.Id = @UserId;

    SELECT TOP(10)
        Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,
        InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId = @UserId AND IsVisible = 1
    ORDER BY CreatedAtUtc DESC, Id DESC;
END
GO

PRINT 'Wallet source withdrawal upgrade completed.';
GO
/* OLX Trade — dashboard referral preview + 5% commission setting
   Run against the existing TahirFxTraderDb database.
*/
USE TahirFxTraderDb;
GO

IF COL_LENGTH('dbo.SystemSettings','ReferralCommissionPercent') IS NULL
BEGIN
    ALTER TABLE dbo.SystemSettings
    ADD ReferralCommissionPercent decimal(9,4) NOT NULL
        CONSTRAINT DF_SystemSettings_ReferralCommission_Preview DEFAULT(5);
END
GO

UPDATE dbo.SystemSettings
SET ReferralCommissionPercent = 5,
    UpdatedAtUtc = SYSUTCDATETIME()
WHERE Id = 1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Referral_PublicSettings_Get
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(ISNULL(ReferralCommissionPercent,5) AS decimal(9,4))
    FROM dbo.SystemSettings
    WHERE Id = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Get @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayStartUtc datetime2(0) = CONVERT(date, SYSUTCDATETIME());
    DECLARE @OpeningProfitBalance decimal(19,4);

    SELECT TOP(1) @OpeningProfitBalance = ProfitBalanceAfter
    FROM dbo.WalletLedger
    WHERE UserId = @UserId
      AND IsVisible = 1
      AND CreatedAtUtc < @TodayStartUtc
    ORDER BY CreatedAtUtc DESC, Id DESC;

    SELECT
        u.FullName,
        u.UserTraceId,
        w.AvailableBalance,
        w.HeldBalance,
        w.InvestmentBalance,
        w.ProfitBalance,
        w.CommissionBalance,
        w.HeldInvestmentBalance,
        w.HeldProfitBalance,
        w.HeldCommissionBalance,
        ISNULL((SELECT SUM(NetAmount) FROM dbo.Deposits WHERE UserId=@UserId AND Status=2),0) TotalDeposits,
        ISNULL((SELECT SUM(Amount) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status=3),0) TotalWithdrawals,
        (SELECT COUNT(*) FROM dbo.Deposits WHERE UserId=@UserId AND Status=0) PendingDeposits,
        (SELECT COUNT(*) FROM dbo.Withdrawals WHERE UserId=@UserId AND Status IN(0,1)) PendingWithdrawals,
        (SELECT COUNT(*) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1) SuccessfulReferralCount,
        ISNULL((SELECT SUM(ReferralCommissionAmount) FROM dbo.Referrals WHERE ReferrerUserId=@UserId AND IsQualified=1),0) ReferralCommissionEarned,
        CAST(ISNULL(s.ReferralCommissionPercent,5) AS decimal(9,4)) ReferralCommissionPercent,
        CAST(w.ProfitBalance - ISNULL(@OpeningProfitBalance, 0) AS decimal(19,4)) TodayPnl,
        CAST(COALESCE(u.WithdrawalFeePercentOverride, s.DefaultWithdrawalFeePercent, 0) AS decimal(9,4)) InvestmentWithdrawalFeePercent
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId = u.Id
    JOIN dbo.SystemSettings s ON s.Id = 1
    WHERE u.Id = @UserId;

    SELECT TOP(10)
        Id,UserId,EntryType,ReferenceNo,Description,Credit,Debit,BalanceAfter,
        InvestmentBalanceAfter,ProfitBalanceAfter,CommissionBalanceAfter,CreatedAtUtc
    FROM dbo.WalletLedger
    WHERE UserId = @UserId AND IsVisible = 1
    ORDER BY CreatedAtUtc DESC, Id DESC;
END
GO

PRINT 'Dashboard referral preview upgrade completed. Referral commission set to 5%.';
GO


/* OLX Trade - Withdrawal Email OTP (included for new installations) */
IF OBJECT_ID(N'dbo.WithdrawalOtpChallenges', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.WithdrawalOtpChallenges
    (
        Id bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_WithdrawalOtpChallenges PRIMARY KEY,
        UserId bigint NOT NULL,
        PaymentMethodId int NOT NULL,
        WalletSource nvarchar(30) NOT NULL,
        Amount decimal(19,4) NOT NULL,
        DestinationJson nvarchar(max) NOT NULL,
        DestinationDisplay nvarchar(300) NOT NULL,
        CodeHash char(64) NOT NULL,
        ExpiresAtUtc datetime2(0) NOT NULL,
        FailedAttempts int NOT NULL CONSTRAINT DF_WithdrawalOtp_FailedAttempts DEFAULT(0),
        IsUsed bit NOT NULL CONSTRAINT DF_WithdrawalOtp_IsUsed DEFAULT(0),
        UsedAtUtc datetime2(0) NULL,
        CreatedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_WithdrawalOtp_CreatedAt DEFAULT(SYSUTCDATETIME()),
        CONSTRAINT FK_WithdrawalOtp_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
        CONSTRAINT FK_WithdrawalOtp_Method FOREIGN KEY(PaymentMethodId) REFERENCES dbo.PaymentMethods(Id),
        CONSTRAINT CK_WithdrawalOtp_Wallet CHECK(WalletSource IN(N'Investment',N'ProfitCommission')),
        CONSTRAINT CK_WithdrawalOtp_Amount CHECK(Amount > 0),
        CONSTRAINT CK_WithdrawalOtp_Json CHECK(ISJSON(DestinationJson)=1),
        CONSTRAINT CK_WithdrawalOtp_Attempts CHECK(FailedAttempts >= 0 AND FailedAttempts <= 5)
    );
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_WithdrawalOtp_User_Active' AND object_id=OBJECT_ID(N'dbo.WithdrawalOtpChallenges'))
CREATE INDEX IX_WithdrawalOtp_User_Active ON dbo.WithdrawalOtpChallenges(UserId, IsUsed, ExpiresAtUtc DESC);
GO

CREATE OR ALTER PROCEDURE dbo.sp_WithdrawalOtp_Create
    @UserId bigint,
    @PaymentMethodId int,
    @WalletSource nvarchar(30),
    @Amount decimal(19,4),
    @DestinationJson nvarchar(max),
    @DestinationDisplay nvarchar(300),
    @CodeHash char(64),
    @ExpiresAtUtc datetime2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @WalletSource NOT IN(N'Investment',N'ProfitCommission')
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Select a valid withdrawal wallet.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF @Amount <= 0
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Enter a valid withdrawal amount.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF ISJSON(@DestinationJson) <> 1
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal destination is invalid.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF @ExpiresAtUtc <= SYSUTCDATETIME()
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'OTP expiry must be in the future.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF EXISTS
    (
        SELECT 1 FROM dbo.WithdrawalOtpChallenges
        WHERE UserId=@UserId AND IsUsed=0 AND ExpiresAtUtc>SYSUTCDATETIME()
          AND CreatedAtUtc>DATEADD(SECOND,-30,SYSUTCDATETIME())
    )
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Please wait 30 seconds before requesting another withdrawal code.' Message,CAST(NULL AS bigint) Id; RETURN; END
    DECLARE
        @CanWithdraw bit,
        @UserStatus int,
        @EmailVerified bit,
        @InvestmentBalance decimal(19,4),
        @ProfitBalance decimal(19,4),
        @CommissionBalance decimal(19,4),
        @UserMin decimal(19,4),
        @UserMax decimal(19,4),
        @UserFee decimal(9,4),
        @DefaultMin decimal(19,4),
        @DefaultMax decimal(19,4),
        @DefaultFee decimal(9,4),
        @MethodMin decimal(19,4),
        @MethodMax decimal(19,4),
        @MethodActive bit,
        @SupportsWithdrawal bit,
        @EffectiveMin decimal(19,4),
        @EffectiveMax decimal(19,4),
        @SourceBalance decimal(19,4),
        @FeePercent decimal(9,4);

    SELECT
        @CanWithdraw=u.CanWithdraw,@UserStatus=u.Status,@EmailVerified=u.IsEmailVerified,
        @UserMin=u.WithdrawalMinOverride,@UserMax=u.WithdrawalMaxOverride,@UserFee=u.WithdrawalFeePercentOverride,
        @InvestmentBalance=w.InvestmentBalance,@ProfitBalance=w.ProfitBalance,@CommissionBalance=w.CommissionBalance
    FROM dbo.Users u
    JOIN dbo.UserWallets w ON w.UserId=u.Id
    WHERE u.Id=@UserId;

    SELECT @DefaultMin=DefaultWithdrawalMin,@DefaultMax=DefaultWithdrawalMax,@DefaultFee=DefaultWithdrawalFeePercent
    FROM dbo.SystemSettings WHERE Id=1;

    SELECT @MethodMin=MinWithdrawal,@MethodMax=MaxWithdrawal,@MethodActive=IsActive,@SupportsWithdrawal=SupportsWithdrawal
    FROM dbo.PaymentMethods WHERE Id=@PaymentMethodId;

    IF ISNULL(@UserStatus,-1)<>1 OR ISNULL(@EmailVerified,0)<>1 OR ISNULL(@CanWithdraw,0)<>1
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawals are disabled for this account.' Message,CAST(NULL AS bigint) Id; RETURN; END
    IF ISNULL(@MethodActive,0)<>1 OR ISNULL(@SupportsWithdrawal,0)<>1
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'The selected withdrawal method is unavailable.' Message,CAST(NULL AS bigint) Id; RETURN; END

    SET @EffectiveMin=CASE WHEN ISNULL(@UserMin,@DefaultMin)>ISNULL(@MethodMin,0) THEN ISNULL(@UserMin,@DefaultMin) ELSE ISNULL(@MethodMin,0) END;
    SET @EffectiveMax=ISNULL(@UserMax,@DefaultMax);
    IF @MethodMax IS NOT NULL AND @MethodMax<@EffectiveMax SET @EffectiveMax=@MethodMax;

    IF @Amount<@EffectiveMin OR @Amount>@EffectiveMax
    BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount is outside your allowed minimum and maximum limits.' Message,CAST(NULL AS bigint) Id; RETURN; END

    IF @WalletSource=N'Investment'
    BEGIN
        SET @SourceBalance=ISNULL(@InvestmentBalance,0);
        SET @FeePercent=COALESCE(@UserFee,@DefaultFee,0);
        IF @Amount-ROUND(@Amount*@FeePercent/100.0,4)<=0
        BEGIN SELECT CAST(0 AS bit) Succeeded,N'Withdrawal amount must be greater than the investment withdrawal fee.' Message,CAST(NULL AS bigint) Id; RETURN; END
    END
    ELSE
    BEGIN
        SET @SourceBalance=ISNULL(@ProfitBalance,0)+ISNULL(@CommissionBalance,0);
    END

    IF @SourceBalance<@Amount
    BEGIN SELECT CAST(0 AS bit) Succeeded,CASE WHEN @WalletSource=N'Investment' THEN N'Insufficient Investment Wallet balance.' ELSE N'Insufficient combined Profit and Commission balance.' END Message,CAST(NULL AS bigint) Id; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.WithdrawalOtpChallenges
        SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME()
        WHERE UserId=@UserId AND IsUsed=0;

        INSERT dbo.WithdrawalOtpChallenges
        (UserId,PaymentMethodId,WalletSource,Amount,DestinationJson,DestinationDisplay,CodeHash,ExpiresAtUtc)
        VALUES(@UserId,@PaymentMethodId,@WalletSource,@Amount,@DestinationJson,@DestinationDisplay,@CodeHash,@ExpiresAtUtc);
        DECLARE @Id bigint=SCOPE_IDENTITY();
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal verification code created.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,CAST(NULL AS bigint) Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_WithdrawalOtp_Get
    @Id bigint,
    @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT o.Id,o.UserId,o.PaymentMethodId,p.Name PaymentMethodName,o.WalletSource,o.Amount,o.DestinationJson,o.DestinationDisplay,
           o.ExpiresAtUtc,o.FailedAttempts,o.IsUsed,o.CreatedAtUtc
    FROM dbo.WithdrawalOtpChallenges o
    JOIN dbo.PaymentMethods p ON p.Id=o.PaymentMethodId
    WHERE o.Id=@Id AND o.UserId=@UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_WithdrawalOtp_Claim
    @Id bigint,
    @UserId bigint,
    @CodeHash char(64)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @StoredHash char(64),@ExpiresAtUtc datetime2(0),@IsUsed bit,@FailedAttempts int;
        SELECT @StoredHash=CodeHash,@ExpiresAtUtc=ExpiresAtUtc,@IsUsed=IsUsed,@FailedAttempts=FailedAttempts
        FROM dbo.WithdrawalOtpChallenges WITH(UPDLOCK,HOLDLOCK)
        WHERE Id=@Id AND UserId=@UserId;

        IF @StoredHash IS NULL
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'Withdrawal verification request not found.' Message,@Id Id; RETURN; END
        IF @IsUsed=1
        BEGIN ROLLBACK; SELECT CAST(0 AS bit) Succeeded,N'This withdrawal code has already been used.' Message,@Id Id; RETURN; END
        IF @ExpiresAtUtc<=SYSUTCDATETIME()
        BEGIN
            UPDATE dbo.WithdrawalOtpChallenges SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
            COMMIT; SELECT CAST(0 AS bit) Succeeded,N'The withdrawal code has expired. Send a new code.' Message,@Id Id; RETURN;
        END
        IF @FailedAttempts>=5
        BEGIN
            UPDATE dbo.WithdrawalOtpChallenges SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
            COMMIT; SELECT CAST(0 AS bit) Succeeded,N'Too many incorrect attempts. Send a new code.' Message,@Id Id; RETURN;
        END
        IF @StoredHash<>@CodeHash
        BEGIN
            UPDATE dbo.WithdrawalOtpChallenges
            SET FailedAttempts=FailedAttempts+1,
                IsUsed=CASE WHEN FailedAttempts+1>=5 THEN 1 ELSE IsUsed END,
                UsedAtUtc=CASE WHEN FailedAttempts+1>=5 THEN SYSUTCDATETIME() ELSE UsedAtUtc END
            WHERE Id=@Id;
            COMMIT; SELECT CAST(0 AS bit) Succeeded,N'Incorrect verification code.' Message,@Id Id; RETURN;
        END

        UPDATE dbo.WithdrawalOtpChallenges SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME() WHERE Id=@Id;
        COMMIT;
        SELECT CAST(1 AS bit) Succeeded,N'Withdrawal code verified.' Message,@Id Id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT CAST(0 AS bit) Succeeded,ERROR_MESSAGE() Message,@Id Id;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_WithdrawalOtp_Cancel
    @Id bigint,
    @UserId bigint
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.WithdrawalOtpChallenges
    SET IsUsed=1,UsedAtUtc=SYSUTCDATETIME()
    WHERE Id=@Id AND UserId=@UserId AND IsUsed=0;
END
GO

PRINT 'Withdrawal email OTP upgrade completed.';
GO
