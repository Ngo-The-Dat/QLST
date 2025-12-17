USE master
GO

USE QLST
GO


-- Bộ phận quản lý kho hàng
CREATE OR ALTER PROCEDURE USP_CANCEL_DAT_HANG_UNREPEATABLE_READ
    @MaHD VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED
    BEGIN TRANSACTION;
    
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM DONDATHANG WHERE MAHD = @MaHD)
        BEGIN
            RAISERROR(N'Lỗi: Mã đơn đặt hàng %s không tồn tại.', 16, 1, @MAHD);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @SoLuongDaNhan INT;
        DECLARE @TrangThai NVARCHAR(30);

        SELECT @SoLuongDaNhan = SOLUONGDANHAN, @TrangThai = TRANGTHAI
        FROM DONDATHANG
        WHERE MAHD = @MaHD

        -- Nếu giao rồi hoặc giao 1 phần thì không hủy đơn được
        IF @SoLuongDaNhan > 0 OR @TrangThai <> N'Chưa giao' 
        BEGIN
            RAISERROR(N'Lỗi: Không thể hủy đơn hàng đã bắt đầu nhập kho hoặc đã hoàn tất.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        PRINT N'Đã đọc trạng thái: ' + @TrangThai;
        PRINT N'Cancel đặt hàng đang chờ 5 giây...'
        WAITFOR DELAY '00:00:5'

        DECLARE @SoLuongDaNhan2 INT;
        DECLARE @TrangThai2 NVARCHAR(30);
        SELECT @SoLuongDaNhan2 = SOLUONGDANHAN, @TrangThai2 = TRANGTHAI
        FROM DONDATHANG
        WHERE MAHD = @MaHD

        PRINT N'Đã đọc trạng thái: ' + @TrangThai2;
        -- Cập nhật thêm số lượng đã nhận hoặc trạng thái

        WAITFOR DELAY '00:00:05'

        IF @TrangThai <> @TrangThai2
        BEGIN
            -- Nếu khác nhau -> In thông báo lỗi của mình tự định nghĩa và dừng lại
            PRINT N'>>> PHÁT HIỆN LỖI UNREPEATABLE READ: Trạng thái đơn đặt hàng đã bị thay đổi!';
            ROLLBACK TRANSACTION; -- Hủy transaction, không cố xóa nữa
            RETURN;
        END

        DELETE FROM DONDATHANG WHERE MAHD = @MaHD

        COMMIT TRANSACTION
        PRINT N'Đã hủy (xóa) đơn đặt hàng ' + @MAHD + N' thành công.';
    END TRY

    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END
GO

SELECT * FROM DONDATHANG
EXEC USP_CANCEL_DAT_HANG_UNREPEATABLE_READ 'DDH02';
SELECT * FROM DONDATHANG