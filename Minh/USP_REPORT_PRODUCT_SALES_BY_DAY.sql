USE QLST
GO

CREATE OR ALTER PROCEDURE USP_REPORT_PRODUCT_SALES_BY_DAY
    @NGAY DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- Dùng REPEATABLE READ
        SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        BEGIN TRANSACTION;

        DECLARE @TongSoKhachHang INT;
        DECLARE @TongDoanhThu BIGINT;

        -- Đọc tất cả dữ liệu cần thiết một lần với HOLDLOCK
        SELECT @TongSoKhachHang = COUNT(DISTINCT MAKH)
        FROM HOADON WITH (HOLDLOCK)
        WHERE CAST(NGAYLAP AS DATE) = @NGAY;

        SELECT @TongDoanhThu = ISNULL(SUM(TONGTIEN), 0)
        FROM HOADON WITH (HOLDLOCK)
        WHERE CAST(NGAYLAP AS DATE) = @NGAY;


        SELECT 
            SP.MASP,
            SP.TENSANPHAM,
            SUM(CTHD.SOLUONG) AS TONG_SO_LUONG_BAN,
            COUNT(DISTINCT HD.MAKH) AS SO_LUONG_KHACH_HANG_MUA
        INTO #TempProductSales
        FROM HOADON HD WITH (HOLDLOCK)
        JOIN CHITIETHOADON CTHD WITH (HOLDLOCK) ON HD.MAHD = CTHD.MAHD
        JOIN SANPHAM SP ON CTHD.MASP = SP.MASP
        WHERE CAST(HD.NGAYLAP AS DATE) = @NGAY
        GROUP BY SP.MASP, SP.TENSANPHAM;

        COMMIT TRANSACTION;

        -- Xử lý và hiển thị kết quả từ temp table (không còn lock)
        PRINT N'Tổng số khách hàng: ' + CAST(@TongSoKhachHang AS NVARCHAR);
        PRINT N'Tổng doanh thu: ' + FORMAT(@TongDoanhThu, 'N0') + N' VNĐ';
        PRINT N'';

        SELECT 
            @NGAY AS NGAY_BAO_CAO,
            @TongSoKhachHang AS TONG_SO_KHACH_HANG,
            @TongDoanhThu AS TONG_DOANH_THU;

        PRINT N'Chi tiết sản phẩm:';
        SELECT 
            MASP,
            TENSANPHAM,
            TONG_SO_LUONG_BAN,
            SO_LUONG_KHACH_HANG_MUA
        FROM #TempProductSales
        ORDER BY TONG_SO_LUONG_BAN DESC;

        DROP TABLE #TempProductSales;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF OBJECT_ID('tempdb..#TempProductSales') IS NOT NULL
            DROP TABLE #TempProductSales;
        
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT N'Lỗi: ' + @ErrMsg;
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO