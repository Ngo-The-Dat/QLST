USE QLST
GO

CREATE OR ALTER PROCEDURE USP_REPORT_LOW_STOCK_ITEMS
    @TY_LE_CANH_BAO FLOAT = 0.7
AS
BEGIN
    SET NOCOUNT ON;

    IF @TY_LE_CANH_BAO <= 0 OR @TY_LE_CANH_BAO > 1
    BEGIN
        PRINT N'Lỗi: Tỷ lệ cảnh báo phải trong khoảng (0, 1]';
        RETURN;
    END

    BEGIN TRY
       
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        BEGIN TRANSACTION;

        -- Đọc nhanh và snapshot vào bảng tạm
        SELECT 
            MASP,
            TENSANPHAM,
            TONKHO,
            SOLUONGTOIDA,
            CAST(TONKHO AS FLOAT) / SOLUONGTOIDA AS TY_LE_TON_KHO
        INTO #TempLowStock
        FROM SANPHAM WITH (NOLOCK)  -- Chấp nhận dirty read để đọc nhanh
        WHERE SOLUONGTOIDA > 0
          AND (CAST(TONKHO AS FLOAT) / SOLUONGTOIDA) < @TY_LE_CANH_BAO;

        COMMIT TRANSACTION;

        DECLARE @SoLuongSanPham INT;
        SELECT @SoLuongSanPham = COUNT(*) FROM #TempLowStock;
        PRINT N'Tỷ lệ cảnh báo: ' + CAST(@TY_LE_CANH_BAO * 100 AS NVARCHAR) + N'%';
        PRINT N'Số lượng SP cảnh báo: ' + CAST(@SoLuongSanPham AS NVARCHAR);
        PRINT N'';

        SELECT 
            MASP,
            TENSANPHAM,
            TONKHO,
            SOLUONGTOIDA,
            CAST(ROUND(TY_LE_TON_KHO * 100, 2) AS DECIMAL(5,2)) AS TY_LE_TON_KHO_PHAN_TRAM
        FROM #TempLowStock
        ORDER BY TY_LE_TON_KHO ASC;

        DROP TABLE #TempLowStock;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF OBJECT_ID('tempdb..#TempLowStock') IS NOT NULL
            DROP TABLE #TempLowStock;
        
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT N'Lỗi: ' + @ErrMsg;
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO