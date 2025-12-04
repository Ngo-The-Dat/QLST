USE QLST
GO

--------------------------------------------------------------------------
-- TEST 1: USP_REPORT_DAILY_SUMMARY (Báo cáo ngày)
--------------------------------------------------------------------------
PRINT N'=== 1. TEST BÁO CÁO NGÀY (Daily Summary) ==='
DECLARE @Today DATE = GETDATE();
DECLARE @MaHD1 VARCHAR(10) = 'HD_TEST_01';
DECLARE @MaHD2 VARCHAR(10) = 'HD_TEST_02';

-- Clean data cũ
DELETE FROM CHITIETHOADON WHERE MAHD IN (@MaHD1, @MaHD2);
DELETE FROM HOADON WHERE MAHD IN (@MaHD1, @MaHD2);

-- Insert dữ liệu cho ngày hôm nay
INSERT INTO HOADON (MAHD, NGAYLAP, MANV, MAKH) VALUES
(@MaHD1, @Today, 'NV03', 'KH01'), 
(@MaHD2, @Today, 'NV03', 'KH03');

INSERT INTO CHITIETHOADON (MAHD, MASP, SOLUONG, THANHTIEN) VALUES
(@MaHD1, 'SP01', 10, 0), -- 10 Sữa
(@MaHD1, 'SP02', 2, 0),  -- 2 Chảo
(@MaHD2, 'SP01', 5, 0);  -- 5 Sữa

PRINT N'   -> Đã tạo xong hóa đơn hôm nay.'
PRINT N'   -> Kết quả chạy Procedure:'

-- Chạy Procedure
EXEC USP_REPORT_DAILY_SUMMARY;
GO

--------------------------------------------------------------------------
-- TEST 2: USP_CANCEL_DAT_HANG (Hủy đơn hàng)
--------------------------------------------------------------------------
PRINT N' '
PRINT N'=== 2. TEST HỦY ĐƠN HÀNG (Cancel Order) ==='

DECLARE @MaDDH_OK VARCHAR(10) = 'DDH_OK';
DECLARE @MaDDH_FAIL VARCHAR(10) = 'DDH_FAIL';

DELETE FROM CHITIETPHIEUNHAP WHERE MAHD IN (@MaDDH_OK, @MaDDH_FAIL);
DELETE FROM DONDATHANG WHERE MAHD IN (@MaDDH_OK, @MaDDH_FAIL);

-- Case 1: Hủy thành công (Chưa nhập hàng)
INSERT INTO DONDATHANG (MAHD, NGAYLAP, SOLUONGDAT, SOLUONGDANHAN, TRANGTHAI, MANV, MASP) 
VALUES (@MaDDH_OK, GETDATE(), 100, 0, N'Chưa giao', 'NV02', 'SP01');

-- Case 2: Hủy thất bại (Đã nhập 1 phần)
INSERT INTO DONDATHANG (MAHD, NGAYLAP, SOLUONGDAT, SOLUONGDANHAN, TRANGTHAI, MANV, MASP) 
VALUES (@MaDDH_FAIL, GETDATE(), 100, 50, N'Đã giao một phần', 'NV02', 'SP01');

-- Thực thi test
PRINT N'   -> Thử hủy đơn hợp lệ:'
EXEC USP_CANCEL_DAT_HANG @MaHD = @MaDDH_OK;

PRINT N'   -> Thử hủy đơn không hợp lệ (Mong đợi báo lỗi):'
BEGIN TRY
    EXEC USP_CANCEL_DAT_HANG @MaHD = @MaDDH_FAIL;
END TRY
BEGIN CATCH
    PRINT N'      [OK] Hệ thống đã chặn thành công với lỗi: ' + ERROR_MESSAGE();
END CATCH
GO

--------------------------------------------------------------------------
-- TEST 3: USP_RUN_MONTHLY_CUSTOMER_UPDATE (Cập nhật tháng & Mã giảm giá)
--------------------------------------------------------------------------
PRINT N' '
PRINT N'=== 3. TEST CẬP NHẬT THÁNG (Monthly Update) ==='

DECLARE @CurrentMonth INT = MONTH(GETDATE());
DECLARE @CurrentYear INT = YEAR(GETDATE());
DECLARE @KhachHangTest VARCHAR(10) = 'KH_TEST';

-- Clean data test
DELETE FROM PHIEUGIAMGIA WHERE MAKH = @KhachHangTest;
DELETE FROM SOTIENTIEU WHERE MAKH = @KhachHangTest;
DELETE FROM KH_THANHVIEN WHERE MAKH = @KhachHangTest;

-- Tạo khách hàng có sinh nhật THÁNG NAY, nhưng đang ở hạng thấp (LV1)
IF NOT EXISTS (SELECT 1 FROM KHACHHANG WHERE MAKH = @KhachHangTest)
    INSERT INTO KHACHHANG (MAKH, HOTEN, SDT, DIACHI, ISTHANHVIEN) VALUES (@KhachHangTest, N'SV Test Mã PG', '0999888777', N'TPHCM', 1);

INSERT INTO KH_THANHVIEN (MAKH, NGAYDANGKY, NGAYSINH, MANV, MACAPDO)
VALUES (@KhachHangTest, DATEFROMPARTS(@CurrentYear - 1, 1, 1), DATEFROMPARTS(2000, @CurrentMonth, 15), 'NV04', 'LV1');

-- Tạo chi tiêu lớn (15tr) để đủ điều kiện lên hạng
INSERT INTO SOTIENTIEU (MAKH, NAM, SOTIENDATIEU)
VALUES (@KhachHangTest, @CurrentYear, 15000000);

-- Tạo một vài phiếu giả định để test logic ID tự tăng (Ví dụ đã có đến số 99)
IF NOT EXISTS (SELECT 1 FROM PHIEUGIAMGIA WHERE MAPG = 'PG00000099')
    INSERT INTO PHIEUGIAMGIA(MAPG, PHANTRAMGIAM, TRANGTHAI, MAKH) VALUES ('PG00000099', 0, 'Old', 'KH01');

PRINT N'   -> Đã tạo KH Test (Sinh nhật tháng này, Tiêu 15tr).'
PRINT N'   -> Đã tạo phiếu mồi PG00000099.'

-- Thực thi Procedure
DECLARE @Output INT;
EXEC USP_RUN_MONTHLY_CUSTOMER_UPDATE @SoLuongThanhVienCapNhat = @Output OUTPUT;

PRINT N'   -> Đã chạy xong. Số khách được cập nhật hạng: ' + CAST(@Output AS NVARCHAR);

-- Kiểm tra kết quả
PRINT N' '
PRINT N'--- KẾT QUẢ KIỂM TRA MÃ PHIẾU GIẢM GIÁ (Mong đợi: PG00000100) ---'
SELECT MAPG, PHANTRAMGIAM, MAKH, TRANGTHAI 
FROM PHIEUGIAMGIA 
WHERE MAKH = 'KH_TEST' OR MAPG = 'PG00000099';

PRINT N' '
PRINT N'--- KẾT QUẢ KIỂM TRA HẠNG THÀNH VIÊN (Mong đợi: LV3/Kim Cuong) ---'
SELECT K.MAKH, K.HOTEN, TV.MACAPDO 
FROM KHACHHANG K JOIN KH_THANHVIEN TV ON K.MAKH = TV.MAKH
WHERE K.MAKH = 'KH_TEST';
GO