USE master
GO

USE QLST
GO

CREATE OR ALTER PROCEDURE USP_REPORT_DAILY_SUMMARY
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION
    BEGIN TRY

        DECLARE 
        @CurrentDate DATE = GETDATE();

        DECLARE @TongKH INT;
        DECLARE @TongDT BIGINT;

        SELECT 
            @TongKH = ISNULL(COUNT(DISTINCT MAKH),0),
            @TongDT = ISNULL(SUM(TONGTIEN), 0)
        FROM HOADON
        WHERE NGAYLAP = CAST(@CurrentDate AS DATE);

        SELECT 
            N'Báo Cáo Ngày' AS TieuDe,
            @CurrentDate AS Ngay,
            @TongKH AS TongKhachHang,
            FORMAT(@TongDT, '#,##0') + ' VND' AS TongDoanhThu;

        WAITFOR DELAY '00:00:05';


        SELECT 
            @TongKH = ISNULL(COUNT(DISTINCT MAKH),0),
            @TongDT = ISNULL(SUM(TONGTIEN), 0)
        FROM HOADON
        WHERE NGAYLAP = CAST(@CurrentDate AS DATE);

        SELECT 
            N'Báo Cáo Ngày' AS TieuDe,
            @CurrentDate AS Ngay,
            @TongKH AS TongKhachHang,
            FORMAT(@TongDT, '#,##0') + ' VND' AS TongDoanhThu;

        COMMIT TRANSACTION

    END TRY

    BEGIN CATCH
        ROLLBACK TRANSACTION
        DECLARE @error NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@error, 16, 1)
    END CATCH
END
GO


SELECT * FROM HOADON

EXEC USP_REPORT_DAILY_SUMMARY
GO

SELECT * FROM HOADON
