USE QLST
GO

CREATE OR ALTER PROCEDURE USP_PROCESS_STOCK_REORDERING
    @MANV VARCHAR(10)
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

	IF NOT EXISTS (SELECT * FROM NHANVIEN WHERE @MANV = MANV)
	BEGIN
		PRINT N'Nhân viên không tồn tại'
		RETURN
	END
	ELSE
	IF (SELECT VAITRO FROM NHANVIEN WHERE @MANV = MANV) <> N'Quản lý kho hàng'
	BEGIN
		PRINT N'Nhân viên không thuộc bộ phận Quản lý kho hàng'
		RETURN
	END

    DECLARE curSP CURSOR FOR
        SELECT MASP, TONKHO, SOLUONGTOIDA
        FROM SANPHAM;

    DECLARE 
        @MASP VARCHAR(10),
        @TONKHO INT,
        @SLMAX INT,
        @NGUONG70 INT,
        @SLDangDat INT,
        @SLCanDat INT,
        @SLToiThieu INT,
        @LastID INT,
        @NewID VARCHAR(10);

    -- Table tạm để trả kết quả
    DECLARE @RESULT TABLE (MASP VARCHAR(10), SOLUONGDAT INT);

    OPEN curSP;
    FETCH NEXT FROM curSP INTO @MASP, @TONKHO, @SLMAX;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRAN;

            -- Tính ngưỡng 70%
            SET @NGUONG70 = (@SLMAX * 70) / 100;

            IF @TONKHO < @NGUONG70
            BEGIN
                -- Đọc số lượng đã đặt nhưng chưa giao
                SELECT @SLDangDat = ISNULL(SUM(SOLUONGDAT - SOLUONGDANHAN), 0)
                FROM DONDATHANG
                WHERE MASP = @MASP;

                -- Tính số lượng cần đặt
                SET @SLCanDat = @NGUONG70 - (@TONKHO + @SLDangDat);

                -- Số lượng tối thiểu = 10%
                SET @SLToiThieu = (@SLMAX * 10) / 100;

                IF @SLCanDat >= @SLToiThieu
                BEGIN
                    -- Lấy mã đơn đặt hàng mới nhất
                    SELECT @LastID = MAX(CAST(SUBSTRING(MAHD, 4, 2) AS INT))
					FROM DONDATHANG;
					
					IF @LastID IS NULL
					BEGIN
					    SET @NewID = 'DDH01';
					END
					ELSE
					BEGIN
					    SET @NewID = 'DDH' + RIGHT('0' + CAST(@LastID + 1 AS VARCHAR(10)), 2);
					END

                    -- Tạo đơn đặt hàng mới
                    INSERT INTO DONDATHANG
                    (MAHD, NGAYLAP, SOLUONGDAT, SOLUONGDANHAN, TRANGTHAI, MANV, MASP)
                    VALUES
                    (@NewID, GETDATE(), @SLCanDat, 0, N'Chưa giao', @MANV, @MASP);

                    -- Lưu kết quả
                    INSERT INTO @RESULT VALUES(@MASP, @SLCanDat);
                END
            END

            COMMIT TRAN;
        END TRY
        BEGIN CATCH
            ROLLBACK TRAN;
            PRINT N'Lỗi xảy ra khi xử lý sản phẩm ' + @MASP;
        END CATCH;

        FETCH NEXT FROM curSP INTO @MASP, @TONKHO, @SLMAX;
    END

    CLOSE curSP;
    DEALLOCATE curSP;

    -- Trả kết quả đặt hàng
    SELECT * FROM @RESULT;
END
GO