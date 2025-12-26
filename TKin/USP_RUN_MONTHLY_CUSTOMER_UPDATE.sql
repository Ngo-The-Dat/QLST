USE master
GO

USE QLST
GO

CREATE OR ALTER PROCEDURE USP_RUN_MONTHLY_CUSTOMER_UPDATE
    @SoLuongThanhVienCapNhat INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentDate DATE = GETDATE();
        DECLARE @CurrentYear INT = YEAR(@CurrentDate);
        DECLARE @CurrentMonth INT = MONTH(@CurrentDate);

        -- CẬP NHẬT CẤP ĐỘ THẺ
        CREATE TABLE #TongTienKH (
            MAKH VARCHAR(10) PRIMARY KEY,
            TONGTIEN INT
        );

        INSERT INTO #TongTienKH(MAKH, TONGTIEN)
        SELECT MAKH, SUM(SOTIENDATIEU)
        FROM SOTIENTIEU -- Chi phí bỏ ra không đáng để lock với sai lệch nhỏ
        WHERE @CurrentYear - NAM BETWEEN 0 AND 1
        GROUP BY MAKH

        ; WITH CalculatedRanks AS (
            SELECT
                TT.MAKH,
                (
                    SELECT TOP 1 CD.MACAPDO
                    FROM CAPDOTHE CD -- Khong doi
                    WHERE TT.TONGTIEN >= CD.TONGTIENTOITHIEU
                    ORDER BY CD.TONGTIENTOITHIEU DESC
                ) AS CapDoMoi
            FROM #TongTienKH TT
        )

        UPDATE KHTV
        SET MACAPDO = C.CapDoMoi
        FROM KH_THANHVIEN KHTV
        JOIN CalculatedRanks C ON KHTV.MAKH = C.MAKH
        WHERE KHTV.MACAPDO <> C.CapDoMoi;

        SET @SoLuongThanhVienCapNhat = @@ROWCOUNT;

        DROP TABLE #TongTienKH;

        -- TẶNG PHIẾU GIẢM GIÁ SINH NHẬT
        DECLARE @MaxCurrentId INT;
        SELECT @MaxCurrentId = ISNULL(MAX(CAST(RIGHT(MAPG, 2) AS INT)), 0)
        FROM PHIEUGIAMGIA WITH (UPDLOCK, HOLDLOCK)
        WHERE MAPG LIKE 'PG[0-9][0-9]';
        
        INSERT INTO PHIEUGIAMGIA(MAPG, PHANTRAMGIAM, TRANGTHAI, MAKH)
        SELECT
            -- GEMINI CHỈ
            'PG' + RIGHT('00' + CAST(@MaxCurrentId + ROW_NUMBER() OVER(ORDER BY MAKH) AS VARCHAR(4)), 2),            
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
                AND YEAR(PG.NGAYTAO) = @CurrentYear
                AND MONTH(PG.NGAYTAO) = @CurrentMonth
            );
        
        COMMIT TRANSACTION;
        PRINT N'Cập nhật khách hàng theo tháng thành công.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#TongTienKH') IS NOT NULL DROP TABLE #TongTienKH;
        DECLARE @error NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@error, 16, 1)
    END CATCH

END;
GO


SELECT KHTV.MAKH, STT.SOTIENDATIEU, MACAPDO
FROM KH_THANHVIEN KHTV
JOIN SOTIENTIEU STT ON STT.MAKH = KHTV.MAKH
WHERE YEAR(CAST(GETDATE() AS DATE)) - NAM <= 1

DECLARE @KQ INT;
EXEC USP_RUN_MONTHLY_CUSTOMER_UPDATE @KQ OUTPUT;
PRINT @KQ

SELECT KHTV.MAKH, STT.SOTIENDATIEU, MACAPDO
FROM KH_THANHVIEN KHTV
JOIN SOTIENTIEU STT ON STT.MAKH = KHTV.MAKH
WHERE YEAR(CAST(GETDATE() AS DATE)) - NAM <= 1

SELECT * from PHIEUGIAMGIA