USE QLST
GO

CREATE OR ALTER PROCEDURE USP_UPDATE_SAN_PHAM
    @MASP VARCHAR(10),
    @TENSANPHAM NVARCHAR(50) = NULL,
    @MOTASP NVARCHAR(MAX) = NULL,
    @DONGIA INT = NULL,
    @PHAN_CHENH_LECH INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Kiểm tra dữ liệu đầu vào
    IF @MASP IS NULL OR LTRIM(RTRIM(@MASP)) = ''
    BEGIN
        PRINT N'Lỗi: Mã sản phẩm không được rỗng';
        RETURN;
    END

    BEGIN TRY
        -- BEGIN TRANSACTION + REPEATABLE READ
        SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        BEGIN TRANSACTION;

        -- Đọc với UPDLOCK + HOLDLOCK
        -- UPDLOCK: Exclusive Intent Lock - ngăn transaction khác UPDATE
        -- HOLDLOCK: Giữ lock đến hết transaction
        DECLARE @TONKHO_HIENTAI INT;
        DECLARE @SOLUONGTOIDA INT;
        DECLARE @TENSANPHAM_CU NVARCHAR(50);
        DECLARE @MOTASP_CU NVARCHAR(MAX);
        DECLARE @DONGIA_CU INT;

        SELECT 
            @TONKHO_HIENTAI = TONKHO,
            @SOLUONGTOIDA = SOLUONGTOIDA,
            @TENSANPHAM_CU = TENSANPHAM,
            @MOTASP_CU = MOTASP,
            @DONGIA_CU = DONGIA
        FROM SANPHAM WITH (UPDLOCK, HOLDLOCK)  -- UPDLOCK
        WHERE MASP = @MASP;

        -- Nếu không tìm thấy sản phẩm
        IF @@ROWCOUNT = 0
        BEGIN
            PRINT N'Lỗi: Không tìm thấy sản phẩm với mã ' + @MASP;
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Tính tồn kho mới
        DECLARE @TONKHO_MOI INT;
        IF @PHAN_CHENH_LECH IS NULL
            SET @TONKHO_MOI = @TONKHO_HIENTAI;
        ELSE
            SET @TONKHO_MOI = @TONKHO_HIENTAI + @PHAN_CHENH_LECH;

        -- Kiểm tra tồn kho mới < 0
        IF @TONKHO_MOI < 0
        BEGIN
            PRINT N'Lỗi: Tồn kho sau cập nhật không được âm (Tồn kho mới: ' + CAST(@TONKHO_MOI AS VARCHAR) + ')';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Kiểm tra tồn kho mới > số lượng tối đa
        IF @TONKHO_MOI > @SOLUONGTOIDA
        BEGIN
            PRINT N'Lỗi: Tồn kho vượt số lượng tối đa (' + 
                  CAST(@TONKHO_MOI AS VARCHAR) + ' > ' + CAST(@SOLUONGTOIDA AS VARCHAR) + ')';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Kiểm tra đơn giá mới <= 0
        IF @DONGIA IS NOT NULL AND @DONGIA <= 0
        BEGIN
            PRINT N'Lỗi: Đơn giá phải lớn hơn 0';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Cập nhật sản phẩm
        UPDATE SANPHAM
        SET 
            TENSANPHAM = CASE WHEN @TENSANPHAM IS NULL THEN @TENSANPHAM_CU ELSE @TENSANPHAM END,
            MOTASP = CASE WHEN @MOTASP IS NULL THEN @MOTASP_CU ELSE @MOTASP END,
            DONGIA = CASE WHEN @DONGIA IS NULL THEN @DONGIA_CU ELSE @DONGIA END,
            TONKHO = @TONKHO_MOI
        WHERE MASP = @MASP;

        -- Ghi nhận thành công và COMMIT
        PRINT N'Cập nhật sản phẩm thành công: ' + @MASP;
        PRINT N'  - Tồn kho: ' + CAST(@TONKHO_HIENTAI AS NVARCHAR) + N' → ' + CAST(@TONKHO_MOI AS NVARCHAR);
        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT N'Lỗi: ' + @ErrMsg;
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO