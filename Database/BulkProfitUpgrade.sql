/* Prevent SQL Server sp_ master-first resolution from using an accidental master copy. */
USE master;
GO
IF OBJECT_ID(N'dbo.sp_Admin_UserProfit_AddAll', N'P') IS NOT NULL DROP PROCEDURE dbo.sp_Admin_UserProfit_AddAll;
GO
USE TahirFxTraderDb;
GO


/* Keep user registration operational even when this script is run independently. */
IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
BEGIN
    DECLARE @UserTraceStart bigint = ISNULL((SELECT MAX(Id) FROM dbo.Users), 0) + 1;
    DECLARE @UserTraceSql nvarchar(max);
    IF @UserTraceStart < 1 SET @UserTraceStart = 1;
    SET @UserTraceSql = N'CREATE SEQUENCE dbo.UserTraceReferenceSeq AS bigint START WITH ' +
                        CONVERT(nvarchar(30), @UserTraceStart) +
                        N' INCREMENT BY 1 NO CYCLE;';
    EXEC sys.sp_executesql @UserTraceSql;
END
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
