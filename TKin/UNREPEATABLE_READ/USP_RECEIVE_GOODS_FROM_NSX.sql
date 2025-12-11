USE QLST
go
-- bảng này là một đơn nhập hàng, có thể dành cho nhiều đơn hàng, có nhiều dòng và mặc định là
-- do cùng 1 nhà sản xuất gửi - do nhà sản xuất đó gửi phiếu này

IF TYPE_ID(N'RECEIVED_ITEM') IS NOT NULL
    DROP TYPE RECEIVED_ITEM;
GO

CREATE TYPE RECEIVED_ITEM AS TABLE 
(
    MAHD VARCHAR(10),      -- Mã hóa đơn (Khớp với kiểu dữ liệu trong bảng DONDATHANG)
    SLNHANTHUCTE INT       -- Số lượng nhận thực tế
)
GO

-- drop procedure if exists USP_RECEIVE_GOODS_FROM_NSX_UNREPEATABLE_READ
-- GO
CREATE OR ALTER procedure USP_RECEIVE_GOODS_FROM_NSX_UNREPEATABLE_READ @v_received_items RECEIVED_ITEM READONLY
AS
BEGIN
BEGIN TRY
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN TRANSACTION 
    DECLARE @MAPN varchar(10)
    DECLARE @MANSX varchar(10)
    DECLARE @Cur_MAHD varchar(10);
    DECLARE @Cur_SL int;       
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
        declare @tonkhohientai INT
        declare @soluongtoida int
        declare @tonkhosaucapnhat int
        SELECT @sldat = SOLUONGDAT, @sldanhan = SOLUONGDANHAN, @Cur_MASP = MASP  
        FROM DONDATHANG
        WHERE mahd = @Cur_MAHD

        SELECT @tonkhohientai = TONKHO, @soluongtoida = soluongtoida 
        FROM sanpham
        WHERE masp = @cur_masp

        -- WAITFOR DELAY '00:00:05'
        SET @tonkhosaucapnhat = @tonkhohientai + @Cur_SL
        if @sldanhan + @Cur_SL > @sldat
        BEGIN
            RAISERROR(N'Lỗi: Số lượng nhập hàng vượt quá yêu cầu đặt', 16, 1);
            ROLLBACK TRAN
            Return
        end
        if @tonkhosaucapnhat > @soluongtoida 
        BEGIN
            RAISERROR(N'Lỗi: Số lượng nhập hàng vượt số lượng tối đa của sản phẩm ', 16, 1);
            ROLLBACK TRAN
            Return
        end
        UPDATE  DONDATHANG
        set SOLUONGDANHAN = SOLUONGDANHAN + @Cur_SL
        where mahd = @Cur_MAHD
        if @sldanhan = 0
        begin
            UPDATE DONDATHANG
            set trangthai = N'Đã giao một phần' where mahd = @Cur_MAHD
        end
        if @sldanhan + @cur_sl = @sldat
        begin
            UPDATE DONDATHANG
            set trangthai = N'Đã giao đủ' where mahd = @Cur_MAHD
        end
        INSERT INTO CHITIETPHIEUNHAP(MAHD, MAPN, SLNHANTHUCTE)
            VALUES (@Cur_MAHD, @MAPN, @Cur_SL);
        UPDATE SANPHAM
        SET TONKHO = @tonkhosaucapnhat
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
-- 1. Khai báo biến kiểu table
DECLARE @listHangNhap RECEIVED_ITEM;

-- 2. Insert dữ liệu vào biến này (Giả sử nhập cho đơn hàng DH001 số lượng 5)
INSERT INTO @listHangNhap (MAHD, SLNHANTHUCTE)
VALUES ('DDH02', 5);

-- 3. Gọi thủ tục với tham số là biến table vừa tạo
SELECT * FROM PHIEUNHAPHANG
SELECT * FROM DONDATHANG
EXEC USP_RECEIVE_GOODS_FROM_NSX_UNREPEATABLE_READ @v_received_items = @listHangNhap;
SELECT * FROM PHIEUNHAPHANG
SELECT * FROM DONDATHANG