USE master
GO

USE QLST
GO

CREATE OR ALTER PROCEDURE USP_RUN_MONTHLY_CUSTOMER_UPDATE
    @SoLuongThanhVienCapNhat INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @CurrentDate DATE = GETDATE();
        DECLARE @CurrentYear INT = YEAR(@CurrentDate);
        DECLARE @CurrentMonth INT = MONTH(@CurrentDate);

        -- CẬP NHẬT CẤP ĐỘ THẺ
        DECLARE @TongTienKH TABLE (
            MAKH VARCHAR(10),
            TONGTIEN INT
        );

        INSERT INTO @TongTienKH(MAKH, TONGTIEN)
        SELECT MAKH, SUM(SOTIENDATIEU)
        FROM SOTIENTIEU
        WHERE @CurrentYear - NAM <= 1
        GROUP BY MAKH

        UPDATE KHTV
        SET MACAPDO = (
            SELECT TOP 1 CD.MACAPDO
            FROM CAPDOTHE CD
            WHERE TT.TONGTIEN >= CD.TONGTIENTOITHIEU
            ORDER BY CD.TONGTIENTOITHIEU DESC
        )
        FROM KH_THANHVIEN KHTV
        JOIN @TongTienKH TT ON KHTV.MAKH = TT.MAKH;

        SET @SoLuongThanhVienCapNhat = @@ROWCOUNT;

        -- TẶNG PHIẾU GIẢM GIÁ SINH NHẬT
        DECLARE @MaxCurrentId INT;
        SELECT @MaxCurrentId = ISNULL(MAX(CAST(RIGHT(MAPG, 8) AS INT)), 0)
        FROM PHIEUGIAMGIA 
        WHERE MAPG LIKE 'PG[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]';
        
        INSERT INTO PHIEUGIAMGIA(MAPG, PHANTRAMGIAM, TRANGTHAI, MAKH)
        SELECT
            -- GEMINI CHỈ
            'PG' + RIGHT('00000000' + CAST(@MaxCurrentId + ROW_NUMBER() OVER(ORDER BY MAKH) AS VARCHAR(10)), 8),            
            CD.PHANTRAMGIAMSN,
            N'Chưa dùng',
            KHTV.MAKH
        FROM KH_THANHVIEN KHTV
        JOIN CAPDOTHE CD ON KHTV.MACAPDO = CD.MACAPDO
        WHERE MONTH(KHTV.NGAYSINH) = @CurrentMonth
            AND CD.PHANTRAMGIAMSN > 0
            -- Chống duplicate
            AND NOT EXISTS (
                SELECT 1 FROM PHIEUGIAMGIA PG
                WHERE KHTV.MAKH = PG.MAKH
                AND MONTH(GETDATE()) = @CurrentMonth
            );
        
        COMMIT TRANSACTION;
        PRINT N'Cập nhật khách hàng theo tháng thành công.';

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @error NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@error, 16, 1)
    END CATCH

END;

GO

DECLARE @KetQua INT;
EXEC USP_RUN_MONTHLY_CUSTOMER_UPDATE @SoLuongThanhVienCapNhat = @KetQua OUTPUT;
PRINT N'Số lượng khách hàng được xét cập nhật hạng: ' + CAST(@KetQua AS NVARCHAR);
