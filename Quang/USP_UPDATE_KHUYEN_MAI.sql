USE QLST
GO

CREATE OR ALTER PROCEDURE USP_UPDATE_KHUYEN_MAI
    @MAKM VARCHAR(10),
    @MASP VARCHAR(10),
    @SOLUONG_MOI INT,
    @TILEGIAM_MOI FLOAT
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN TRAN;

    BEGIN TRY
        -- 1. ĐỌC CHITIETKM VỚI UPDLOCK
        IF NOT EXISTS (
            SELECT 1
            FROM CHITIETKM WITH (UPDLOCK, ROWLOCK)
            WHERE MAKM = @MAKM AND MASP = @MASP
        )
        BEGIN
            PRINT N'Sản phẩm không thuộc khuyến mãi';
            ROLLBACK TRAN;
            RETURN;
        END

        -- 2. Kiểm tra hạn khuyến mãi
        DECLARE @NGAYKT DATE;

        SELECT @NGAYKT = NGAYKETTHUC
        FROM KHUYENMAI         
        WHERE MAKM = @MAKM;

        IF @NGAYKT < GETDATE()
        BEGIN
            PRINT N'Khuyến mãi đã hết hạn';
            ROLLBACK TRAN;
            RETURN;
        END

        -- 3. Kiểm tra tồn kho sản phẩm
        DECLARE @TONKHO INT;

        SELECT @TONKHO = TONKHO
        FROM SANPHAM          
        WHERE MASP = @MASP;

        IF @SOLUONG_MOI > @TONKHO
        BEGIN
            PRINT N'Số lượng khuyến mãi vượt quá tồn kho';
            ROLLBACK TRAN;
            RETURN;
        END

        -- 4. CẬP NHẬT CHITIETKM
        UPDATE CHITIETKM
        SET SOLUONG = @SOLUONG_MOI,
            TILEGIAM = @TILEGIAM_MOI
        WHERE MAKM = @MAKM AND MASP = @MASP;

        -- 5. ĐỌC lại CHITIETKM để xuất kết quả
        SELECT *
        FROM CHITIETKM
        WHERE MAKM = @MAKM AND MASP = @MASP;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        PRINT N'Lỗi khi cập nhật khuyến mãi';
    END CATCH
END
GO