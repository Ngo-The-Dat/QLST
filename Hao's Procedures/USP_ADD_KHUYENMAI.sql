USE QLST
GO

DROP PROCEDURE IF EXISTS USP_ADD_KHUYEN_MAI
GO

CREATE PROCEDURE USP_ADD_KHUYEN_MAI
    @MAKM VARCHAR(10),
    @MANV VARCHAR(10),
    @NGAYBATDAU DATE,
    @NGAYKETTHUC DATE,
    @ISMEMBER BIT 
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @NGAYKETTHUC < @NGAYBATDAU
        BEGIN
            RAISERROR(N'Lỗi: Ngày kết thúc khuyến mãi phải lớn hơn hoặc bằng ngày bắt đầu.', 16, 1);
            RETURN;
        END
        IF EXISTS (SELECT 1 FROM KHUYENMAI WHERE MAKM = @MAKM)
        BEGIN
            RAISERROR(N'Lỗi: Mã khuyến mãi này đã tồn tại trong hệ thống.', 16, 1);
            RETURN;
        END
        IF NOT EXISTS (SELECT 1 FROM NHANVIEN WHERE MANV = @MANV)
        BEGIN
            RAISERROR(N'Lỗi: Mã nhân viên không tồn tại.', 16, 1);
            RETURN;
        END
        INSERT INTO KHUYENMAI (MAKM, NGAYBATDAU, NGAYKETTHUC, MANV, ISMEMBER)
        VALUES (@MAKM, @NGAYBATDAU, @NGAYKETTHUC, @MANV, @ISMEMBER);

        PRINT N'Thêm đợt khuyến mãi thành công: ' + @MAKM;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO