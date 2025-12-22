USE master
GO

USE QLST
GO


-- Bộ phận quản lý kho hàng
CREATE OR ALTER PROCEDURE USP_CANCEL_DAT_HANG_PHANTOM
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

        WAITFOR DELAY '00:00:05'


        DECLARE @SoLuongDaNhan INT;
        DECLARE @TrangThai NVARCHAR(30);

        SELECT @SoLuongDaNhan = SOLUONGDANHAN, @TrangThai = TRANGTHAI
        FROM DONDATHANG
        WHERE MAHD = @MaHD

        PRINT @SOLUONGDANHAN
        -- Nếu giao rồi hoặc giao 1 phần thì không hủy đơn được
        IF @SoLuongDaNhan > 0 OR @TrangThai <> N'Chưa giao' 
        BEGIN
            RAISERROR(N'Lỗi: Không thể hủy đơn hàng đã bắt đầu nhập kho hoặc đã hoàn tất.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM DONDATHANG WHERE MAHD = @MaHD)
        BEGIN
            RAISERROR(N'Lỗi: Mã đơn đặt hàng %s không tồn tại.', 16, 1, @MAHD);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        -- Cập nhật thêm số lượng đã nhận hoặc trạng thái
        DELETE FROM DONDATHANG WHERE MAHD = @MaHD

        PRINT N'Đã hủy (xóa) đơn đặt hàng ' + @MAHD + N' thành công.';
        COMMIT TRANSACTION
    END TRY

    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END
GO
