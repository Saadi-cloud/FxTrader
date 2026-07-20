USE TahirFxTraderDb;
GO

DECLARE @NextTraceNumber bigint = ISNULL((SELECT MAX(Id) FROM dbo.Users), 0) + 1;
DECLARE @Sql nvarchar(max);

IF @NextTraceNumber < 1 SET @NextTraceNumber = 1;

IF OBJECT_ID(N'dbo.UserTraceReferenceSeq', N'SO') IS NULL
BEGIN
    SET @Sql = N'CREATE SEQUENCE dbo.UserTraceReferenceSeq AS bigint START WITH ' +
               CONVERT(nvarchar(30), @NextTraceNumber) +
               N' INCREMENT BY 1 NO CYCLE;';

    EXEC sys.sp_executesql @Sql;
END
GO

SELECT name, current_value, increment
FROM sys.sequences
WHERE object_id = OBJECT_ID(N'dbo.UserTraceReferenceSeq');
GO
