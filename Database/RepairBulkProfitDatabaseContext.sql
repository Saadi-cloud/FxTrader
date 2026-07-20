/*
  OLX Trade - repair bulk-profit database context.

  Why this is needed:
  Application procedure names begin with sp_. SQL Server may search master first
  for unqualified sp_ procedure names. If a copy was accidentally created in
  master, it can run there and fail with: Invalid object name 'dbo.Users'.

  This script removes stray master copies and recreates the bulk-profit procedure
  in TahirFxTraderDb. It is safe to run more than once.
*/
USE master;
GO

IF OBJECT_ID(N'dbo.sp_Admin_UserProfit_AddAll', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_UserProfit_AddAll;
GO
IF OBJECT_ID(N'dbo.sp_Admin_UserProfit_Add', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_UserProfit_Add;
GO
IF OBJECT_ID(N'dbo.sp_Admin_UserBalances_GetAll', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_UserBalances_GetAll;
GO
IF OBJECT_ID(N'dbo.sp_Admin_UserBalance_Get', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_UserBalance_Get;
GO

IF DB_ID(N'TahirFxTraderDb') IS NULL
    THROW 51000, 'Database TahirFxTraderDb does not exist on this SQL Server instance.', 1;
GO

USE TahirFxTraderDb;
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
    THROW 51001, 'dbo.Users is missing from TahirFxTraderDb. Run Database/FXTraderDb.sql on the same SQL Server instance used by the application.', 1;
GO
IF OBJECT_ID(N'dbo.UserWallets', N'U') IS NULL
    THROW 51002, 'dbo.UserWallets is missing. Run ProfitBalanceUpgrade.sql first.', 1;
GO
IF OBJECT_ID(N'dbo.ProfitAllocations', N'U') IS NULL
    THROW 51003, 'dbo.ProfitAllocations is missing. Run ProfitBalanceUpgrade.sql first.', 1;
GO
IF OBJECT_ID(N'dbo.ProfitBatches', N'U') IS NULL
    THROW 51004, 'dbo.ProfitBatches is missing. Run BulkProfitUpgrade.sql first.', 1;
GO
IF COL_LENGTH(N'dbo.UserWallets', N'InvestmentBalance') IS NULL
    THROW 51005, 'InvestmentBalance is missing. Run ProfitBalanceUpgrade.sql first.', 1;
GO
IF COL_LENGTH(N'dbo.UserWallets', N'ProfitBalance') IS NULL
    THROW 51006, 'ProfitBalance is missing. Run ProfitBalanceUpgrade.sql first.', 1;
GO

IF OBJECT_ID(N'dbo.ProfitBatchReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.ProfitBatchReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
GO
IF OBJECT_ID(N'dbo.ProfitReferenceSeq', N'SO') IS NULL
    CREATE SEQUENCE dbo.ProfitReferenceSeq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
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
        FROM dbo.Users AS u
        INNER JOIN dbo.Roles AS r ON r.Id=u.RoleId
        INNER JOIN dbo.UserWallets AS w WITH(UPDLOCK,HOLDLOCK) ON w.UserId=u.Id
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
        FROM #Eligible AS e;

        UPDATE w
        SET w.ProfitBalance=w.ProfitBalance+e.ProfitAmount,
            w.AvailableBalance=w.AvailableBalance+e.ProfitAmount,
            w.UpdatedAtUtc=SYSUTCDATETIME()
        FROM dbo.UserWallets AS w
        INNER JOIN #Eligible AS e ON e.UserId=w.UserId;

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
        FROM @Allocated AS a
        INNER JOIN dbo.UserWallets AS w ON w.UserId=a.UserId;

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

SELECT
    DB_NAME() AS CurrentDatabase,
    OBJECT_SCHEMA_NAME(OBJECT_ID(N'dbo.sp_Admin_UserProfit_AddAll')) AS ProcedureSchema,
    OBJECT_NAME(OBJECT_ID(N'dbo.sp_Admin_UserProfit_AddAll')) AS ProcedureName,
    CASE WHEN OBJECT_ID(N'dbo.Users',N'U') IS NOT NULL THEN N'Present' ELSE N'Missing' END AS UsersTable;
GO
