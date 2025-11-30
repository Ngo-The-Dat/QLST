drop procedure if exists USP_CANCEL_ORDER
GO
create procedure USP_CANCEL_ORDER @mahd varchar(10)
AS
BEGIN
    if not exists (select 1 from hoadon where  mahd = @mahd)
    BEGIN
        print N'Hóa đon không tồn tại'
        RETURN
    END
    begin try
    begin TRANSACTION
        DECLARE @cur_masp varchar(10)
        DECLARE @cur_soluong int 
        DECLARE @cur_makm varchar(10)
        DECLARE @makh varchar(10)
        DECLARE @tongtien INT
        DECLARE @mapg varchar(10)
        DECLARE @nam_hoadon INT
        SELECT @makh = MAKH, 
               @tongtien = TONGTIEN, 
               @mapg = MAPG,
               @nam_hoadon = YEAR(NGAYLAP)
        FROM HOADON 
        WHERE MAHD = @mahd
               -- cap nhat lai chi tieu khach hang
        IF @makh IS NOT NULL AND @tongtien > 0
        BEGIN
            UPDATE SOTIENTIEU
            SET SOTIENDATIEU = SOTIENDATIEU - @tongtien
            WHERE MAKH = @makh AND NAM = @nam_hoadon;
        END
                -- neu khach hang su dung ma giam gia cho don nay phai hoan lai 
        IF @mapg IS NOT NULL
        BEGIN
            UPDATE PHIEUGIAMGIA
            SET TRANGTHAI = N'Chưa dùng'
            WHERE MAPG = @mapg;
        END
        DECLARE cur_chitietdon CURSOR FOR 
            SELECT MASP, SOLUONG, MAKM FROM CHITIETHOADON WHERE MAHD = @mahd;
        OPEN cur_chitietdon
        FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- A. CẬP NHẬT TỒN KHO & KHUYẾN MÃI
            -- Thực tế: Chỉ cần DELETE dòng chi tiết này là xong.
            -- Lý do: 
            -- 1. Trigger "TRG_QUANLY_TONKHO_FULL" sẽ tự bắt sự kiện DELETE để cộng lại Tồn kho.
            -- 2. Khuyến mãi (Số lượng giới hạn) thường được tính toán dựa trên COUNT/SUM dữ liệu thực tế.
            --    Khi xóa dòng này đi, số lượng đã bán giảm xuống -> Suất khuyến mãi tự động nhả ra.
            IF @cur_makm IS NOT NULL
            BEGIN
                -- chỉ tối đa có 3 sản phẩm khuyến mãi
                if @cur_soluong > 3 
                BEGIN 
                    UPDATE CHITIETKM 
                    SET SOLUONG = SOLUONG + 3
                    WHERE MAKM = @cur_makm AND MASP = @cur_masp;
                end
                else
                begin
                    UPDATE CHITIETKM 
                    SET SOLUONG = SOLUONG + @cur_soluong
                    WHERE MAKM = @cur_makm AND MASP = @cur_masp;
                end
            END
            DELETE FROM CHITIETHOADON 
            WHERE MAHD = @mahd AND MASP = @cur_masp;

--            UPDATE SANPHAM
--            SET TONKHO = TONKHO + @cur_soluong
--            WHERE MASP = @cur_masp;
--            DELETE FROM HOADON WHERE MAHD = @mahd;           
            FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong
        END
    commit transaction
    end TRY
    begin catch

    end catch
end
go