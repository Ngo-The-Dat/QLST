USE QLST
GO

CREATE OR ALTER PROCEDURE USP_ADD_SAN_PHAM_TO_KHUYEN_MAI
    @MAKM VARCHAR(10),
    @MASP VARCHAR(10),
    @SOLUONG INT,        
    @TILEGIAM FLOAT      
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @SOLUONG <= 0
        BEGIN
            RAISERROR(N'Lỗi: Số lượng khuyến mãi phải lớn hơn 0.', 16, 1);
            RETURN;
        END

        IF @TILEGIAM <= 0 OR @TILEGIAM > 1
        BEGIN
            RAISERROR(N'Lỗi: Tỉ lệ giảm giá phải từ 0 đến 1 (VD: 0.1 = 10%).', 16, 1);
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM KHUYENMAI WHERE MAKM = @MAKM)
        BEGIN
            RAISERROR(N'Lỗi: Mã khuyến mãi không tồn tại.', 16, 1);
            RETURN;
        END

        DECLARE @TonKhoHienTai INT;
        SELECT @TonKhoHienTai = TONKHO 
        FROM SANPHAM 
        WHERE MASP = @MASP;

        IF @TonKhoHienTai IS NULL
        BEGIN
            RAISERROR(N'Lỗi: Mã sản phẩm không tồn tại.', 16, 1);
            RETURN;
        END

        IF @SOLUONG > @TonKhoHienTai
        BEGIN
            DECLARE @Msg NVARCHAR(200) = N'Lỗi: Số lượng khuyến mãi (' + CAST(@SOLUONG AS NVARCHAR) + 
                                         N') lớn hơn tồn kho hiện tại (' + CAST(@TonKhoHienTai AS NVARCHAR) + N').';
            RAISERROR(@Msg, 16, 1);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM CHITIETKM WHERE MAKM = @MAKM AND MASP = @MASP)
        BEGIN
            RAISERROR(N'Lỗi: Sản phẩm này đã được thêm vào đợt khuyến mãi này rồi.', 16, 1);
            RETURN;
        END
        
        INSERT INTO CHITIETKM (MASP, MAKM, SOLUONG, TILEGIAM)
        VALUES (@MASP, @MAKM, @SOLUONG, @TILEGIAM);

        PRINT N'Đã thêm sản phẩm ' + @MASP + N' vào đợt KM ' + @MAKM;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO