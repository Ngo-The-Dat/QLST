USE master
GO

USE QLST
GO

CREATE OR ALTER PROCEDURE USP_REPORT_DAILY_SUMMARY
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    BEGIN TRY

        DECLARE 
        @CurrentDate DATE = GETDATE();

        DECLARE @TongKH INT;
        DECLARE @TongDT BIGINT;

        SELECT 
            @TongKH = ISNULL(COUNT(DISTINCT MAKH),0),
            @TongDT = ISNULL(SUM(TONGTIEN), 0)
        FROM HOADON
        WHERE NGAYLAP = @CurrentDate;

        SELECT 
            N'Báo Cáo Ngày' AS TieuDe,
            @CurrentDate AS Ngay,
            @TongKH AS TongKhachHang,
            FORMAT(@TongDT, '#,##0') + ' VND' AS TongDoanhThu;

        SELECT 
            SP.MASP, 
            SP.TENSANPHAM, 
            SUM(CTHD.SOLUONG) AS SoLuongBan, 
            COUNT(DISTINCT MAKH) AS SoKhachMua,
            FORMAT(SUM(CTHD.THANHTIEN), '#,##0') AS DoanhThuSanPham
        FROM SANPHAM SP
        JOIN CHITIETHOADON CTHD ON CTHD.MASP = SP.MASP
        JOIN HOADON HD ON CTHD.MAHD = HD.MAHD
        WHERE HD.NGAYLAP = @CurrentDate
        GROUP BY SP.MASP, SP.TENSANPHAM
        ORDER BY SoLuongBan DESC;

    END TRY

    BEGIN CATCH
        DECLARE @error NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@error, 16, 1)
    END CATCH
END

GO