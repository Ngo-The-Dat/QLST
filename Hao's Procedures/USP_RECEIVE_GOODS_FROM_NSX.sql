-- bảng này là một đơn nhập hàng, có thể dành cho nhiều đơn hàng, có nhiều dòng và mặc định là
-- do cùng 1 nhà sản xuất gửi - do nhà sản xuất đó gửi phiếu này
IF TYPE_ID(N'RECEIVED_ITEM') IS NULL
BEGIN
    CREATE TYPE RECEIVED_ITEM AS TABLE
    (
        MAHD VARCHAR(10),    
        SLNHANTHUCTE INT
    )
END
GO

use QLST
GO
drop procedure if exists USP_RECEIVE_GOODS_FROM_NSX
GO
create procedure USP_RECEIVE_GOODS_FROM_NSX @v_received_items RECEIVED_ITEM READONLY
AS
BEGIN TRY
    BEGIN TRANSACTION 
    DECLARE @MAPN varchar(10)
    DECLARE @MANSX varchar(10)
    DECLARE @Cur_MAHD varchar(10);
        DECLARE @Cur_SL int;       -- Số lượng nhập dòng hiện tại
        DECLARE @Cur_MASP VARCHAR(10);
    SELECT TOP 1 @MANSX = SP.MANSX
        FROM @v_received_items L
        JOIN DONDATHANG DDH ON L.MAHD = DDH.MAHD
        JOIN SANPHAM SP ON DDH.MASP = SP.MASP;
    SET @MAPN = 'PN' + LEFT(REPLACE(CAST(NEWID() AS VARCHAR(50)), '-', ''), 8);
        
        INSERT INTO PHIEUNHAPHANG (MAPN, MANSX)
        VALUES (@MAPN, @MANSX);
    DECLARE cur_HangNhap CURSOR FOR 
        SELECT MAHD, SLNHANTHUCTE 
        FROM @v_received_items;
    OPEN cur_HangNhap;
    FETCH NEXT FROM cur_HangNhap INTO @Cur_MAHD, @Cur_SL;
    WHILE @@FETCH_STATUS = 0 
    BEGIN
        declare @sldanhan int 
        declare @sldat int
        SELECT @sldat = SOLUONGDAT, @sldanhan = SOLUONGDANHAN,@Cur_MASP = MASP from DONDATHANG where mahd = @Cur_MAHD
        if @sldanhan + @Cur_SL > @sldat
        BEGIN
            RAISERROR(N'Lỗi: Số lượng nhập hàng vượt quá yêu cầu đặt', 16, 1);
            ROLLBACK TRAN
            Return
        end
        -- trigger
        -- UPDATE  DONDATHANG
        -- set SOLUONGDANHAN = SOLUONGDANHAN + @Cur_SL
        -- where mahd = @Cur_MAHD
        -- if @sldanhan = 0
        -- begin
        --     UPDATE DONDATHANG
        --     set trangthai = N'Đã giao một phần' where mahd = @Cur_MAHD
        -- end
        -- if @sldanhan + @cur_sl = @sldat
        -- begin
        --     UPDATE DONDATHANG
        --     set trangthai = N'Đã giao đủ' where mahd = @Cur_MAHD
        -- end
        INSERT INTO CHITIETPHIEUNHAP(MAHD, MAPN, SLNHANTHUCTE)
            VALUES (@Cur_MAHD, @MAPN, @Cur_SL);

        UPDATE SANPHAM
        SET TONKHO = TONKHO + @Cur_SL
        WHERE MASP = @Cur_MASP;
        FETCH NEXT FROM cur_HangNhap INTO @Cur_MAHD, @Cur_SL;
    END
    CLOSE cur_HangNhap;
    DEALLOCATE cur_HangNhap;
    COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global','cur_HangNhap') >= -1
        BEGIN
            CLOSE cur_HangNhap;
            DEALLOCATE cur_HangNhap;
        END

        -- Kiểm tra xem có transaction nào đang chạy không trước khi rollback
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END

GO