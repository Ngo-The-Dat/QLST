USE QLST
GO
CREATE OR ALTER PROCEDURE USP_CANCEL_ORDER 
    @mahd varchar(10)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION
        IF NOT EXISTS (SELECT 1 FROM HOADON WHERE MAHD = @mahd)
        BEGIN
            PRINT N'Hóa đơn không tồn tại'
            ROLLBACK TRANSACTION
            RETURN
        END

        DECLARE @cur_masp varchar(10), @cur_soluong int, @cur_makm varchar(10)
        DECLARE @makh varchar(10), @mapg varchar(10)

        SELECT @makh = MAKH, @mapg = MAPG FROM HOADON WHERE MAHD = @mahd

        IF @mapg IS NOT NULL
        BEGIN
            UPDATE PHIEUGIAMGIA SET TRANGTHAI = N'Chưa dùng' WHERE MAPG = @mapg;
        END

        DECLARE cur_chitietdon CURSOR LOCAL FOR 
            SELECT MASP, SOLUONG, MAKM 
            FROM CHITIETHOADON 
            WHERE MAHD = @mahd
            ORDER BY MASP; -- giải quyết deadlock
        
        OPEN cur_chitietdon
        FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @sl_tonkho_hientai int, @sl_tonkho_toida int
            SELECT @sl_tonkho_hientai = tonkho, @sl_tonkho_toida = SOLUONGTOIDA 
            FROM SANPHAM WITH (UPDLOCK)  -- giải quyết lost update, unrepeatable read
            WHERE masp = @cur_masp

            IF @cur_makm IS NOT NULL
            BEGIN
                DECLARE @Sl_Hoan_KM INT = CASE WHEN @cur_soluong > 3 THEN 3 ELSE @cur_soluong END;
                UPDATE CHITIETKM 
                SET SOLUONG = SOLUONG + @Sl_Hoan_KM
                WHERE MAKM = @cur_makm AND MASP = @cur_masp;
            END

            DECLARE @SL_tonkho_saucapnhat int = @sl_tonkho_hientai + @cur_soluong
            IF @SL_tonkho_saucapnhat > @sl_tonkho_toida 
            BEGIN
                RAISERROR(N'Vượt quá tồn kho tối đa khi hoàn hàng', 16, 1)
                ROLLBACK TRANSACTION
                RETURN
            END

            UPDATE SANPHAM SET TONKHO = @SL_tonkho_saucapnhat WHERE MASP = @cur_masp;
            
            FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm
        END
        
        CLOSE cur_chitietdon
        DEALLOCATE cur_chitietdon

        DELETE FROM CHITIETHOADON WHERE MAHD = @mahd;
        DELETE FROM HOADON WHERE MAHD = @mahd; 

        COMMIT TRANSACTION
        PRINT N'Hủy đơn hàng thành công.'
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE USP_CANCEL_ORDER_WAIT
    @mahd varchar(10)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION
        IF NOT EXISTS (SELECT 1 FROM HOADON WHERE MAHD = @mahd)
        BEGIN
            PRINT N'Hóa đơn không tồn tại'
            ROLLBACK TRANSACTION
            RETURN
        END

        DECLARE @cur_masp varchar(10), @cur_soluong int, @cur_makm varchar(10)
        DECLARE @makh varchar(10), @mapg varchar(10)

        SELECT @makh = MAKH, @mapg = MAPG FROM HOADON WHERE MAHD = @mahd

        IF @mapg IS NOT NULL
        BEGIN
            UPDATE PHIEUGIAMGIA SET TRANGTHAI = N'Chưa dùng' WHERE MAPG = @mapg;
        END

        DECLARE cur_chitietdon CURSOR LOCAL FOR 
            SELECT MASP, SOLUONG, MAKM 
            FROM CHITIETHOADON 
            WHERE MAHD = @mahd
            ORDER BY MASP; -- giải quyết deadlock
        
        OPEN cur_chitietdon
        FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @sl_tonkho_hientai int, @sl_tonkho_toida int
            SELECT @sl_tonkho_hientai = tonkho, @sl_tonkho_toida = SOLUONGTOIDA 
            FROM SANPHAM WITH (UPDLOCK)  -- giải quyết lost update, unrepeatable read
            WHERE masp = @cur_masp

            IF @cur_makm IS NOT NULL
            BEGIN
                DECLARE @Sl_Hoan_KM INT = CASE WHEN @cur_soluong > 3 THEN 3 ELSE @cur_soluong END;
                UPDATE CHITIETKM 
                SET SOLUONG = SOLUONG + @Sl_Hoan_KM
                WHERE MAKM = @cur_makm AND MASP = @cur_masp;
            END

            DECLARE @SL_tonkho_saucapnhat int = @sl_tonkho_hientai + @cur_soluong
            IF @SL_tonkho_saucapnhat > @sl_tonkho_toida 
            BEGIN
                RAISERROR(N'Vượt quá tồn kho tối đa khi hoàn hàng', 16, 1)
                ROLLBACK TRANSACTION
                RETURN
            END
            WAITFOR DELAY '00:00:05'
            UPDATE SANPHAM SET TONKHO = @SL_tonkho_saucapnhat WHERE MASP = @cur_masp;
            
            FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm
        END
        
        CLOSE cur_chitietdon
        DEALLOCATE cur_chitietdon

        DELETE FROM CHITIETHOADON WHERE MAHD = @mahd;
        DELETE FROM HOADON WHERE MAHD = @mahd; 

        COMMIT TRANSACTION
        PRINT N'Hủy đơn hàng thành công.'
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO
-- code cũ mô phỏng tranh chấp
-- CREATE OR ALTER PROCEDURE USP_CANCEL_ORDER 
--     @mahd varchar(10)
-- AS
-- BEGIN
--     SET NOCOUNT ON;

--     -- Kiểm tra tồn tại
--     IF NOT EXISTS (SELECT 1 FROM HOADON WHERE MAHD = @mahd)
--     BEGIN
--         PRINT N'Hóa đơn không tồn tại'
--         RETURN
--     END

--     BEGIN TRY
--         BEGIN TRANSACTION
--         DECLARE @cur_masp varchar(10)
--         DECLARE @cur_soluong int 
--         DECLARE @cur_makm varchar(10)
--         DECLARE @makh varchar(10)
--         DECLARE @mapg varchar(10)
--         DECLARE @nam_hoadon INT

--         SELECT @makh = MAKH, @mapg = MAPG, @nam_hoadon = YEAR(NGAYLAP)
--         FROM HOADON WHERE MAHD = @mahd

--         IF @mapg IS NOT NULL
--         BEGIN
--             UPDATE PHIEUGIAMGIA
--             SET TRANGTHAI = N'Chưa dùng'
--             WHERE MAPG = @mapg;
--         END

--         DECLARE cur_chitietdon CURSOR LOCAL FOR 
--             SELECT MASP, SOLUONG, MAKM FROM CHITIETHOADON WHERE MAHD = @mahd;
        
--         OPEN cur_chitietdon
--         FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm

--         WHILE @@FETCH_STATUS = 0
--         BEGIN
--             IF @cur_makm IS NOT NULL
--             BEGIN
--                 DECLARE @Sl_Hoan_KM INT;
--                 IF @cur_soluong > 3 SET @Sl_Hoan_KM = 3; ELSE SET @Sl_Hoan_KM = @cur_soluong;

--                 UPDATE CHITIETKM 
--                 SET SOLUONG = SOLUONG + @Sl_Hoan_KM
--                 WHERE MAKM = @cur_makm AND MASP = @cur_masp;
--             END
--             declare @SL_tonkho_hientai int
--             declare @sl_tonkho_toida int
--             select @sl_tonkho_hientai = tonkho, @sl_tonkho_toida = SOLUONGTOIDA from sanpham  where masp = @cur_masp
--             declare @SL_tonkho_saucapnhat int 
--             set @SL_tonkho_saucapnhat = @sl_tonkho_hientai  + @cur_soluong
--             if @SL_tonkho_saucapnhat > @sl_tonkho_toida 
--             BEGIN
--                 ROLLBACK tran
--                 return
--             end
--             UPDATE SANPHAM 
--             SET TONKHO = @SL_tonkho_saucapnhat
--             WHERE MASP = @cur_masp;
--             DELETE FROM CHITIETHOADON 
--             WHERE MAHD = @mahd AND MASP = @cur_masp;
--             FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm
--         END
        
--         CLOSE cur_chitietdon
--         DEALLOCATE cur_chitietdon
--         DELETE FROM HOADON WHERE MAHD = @mahd; 

--         COMMIT TRANSACTION
--         PRINT N'Hủy đơn hàng thành công.'
--     END TRY
--     BEGIN CATCH
--         IF @@TRANCOUNT > 0 
--         BEGIN
--             ROLLBACK TRANSACTION;
--         END
        
--         DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
--         RAISERROR(@ErrMsg, 16, 1);
--     END CATCH
-- END
-- GO


