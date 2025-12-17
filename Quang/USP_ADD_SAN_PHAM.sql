USE QLST
GO

CREATE OR ALTER PROCEDURE USP_ADD_SAN_PHAM
    @MASP VARCHAR(10),
    @MADM VARCHAR(10),
    @TENSP NVARCHAR(50),
    @DONGIA INT,
    @MOTASP NVARCHAR(MAX),
    @TONKHO INT,
    @SOLUONGTOIDA INT,
    @NHASANXUAT VARCHAR(10)
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    BEGIN TRAN;

    BEGIN TRY
        -- 1. Kiểm tra mã sản phẩm có tồn tại chưa
        IF EXISTS (
            SELECT 1
            FROM SANPHAM
            WHERE MASP = @MASP
        )
        BEGIN
            PRINT N'Mã sản phẩm đã tồn tại.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- 2. Nếu chưa tồn tại → kiểm tra danh mục
        IF NOT EXISTS (
            SELECT 1
            FROM DANHMUC
            WHERE MADM = @MADM
        )
        BEGIN
            PRINT N'Danh mục không tồn tại.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- 3. Kiểm tra nhà sản xuất
        IF NOT EXISTS (
            SELECT 1
            FROM NHASANXUAT
            WHERE MANSX = @NHASANXUAT
        )
        BEGIN
            PRINT N'Nhà sản xuất không tồn tại.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- 4. Kiểm tra số lượng tồn kho ≤ số lượng tối đa
        IF @TONKHO > @SOLUONGTOIDA
        BEGIN
            PRINT N'Số lượng tồn kho vượt quá số lượng tối đa.';
            ROLLBACK TRAN;
            RETURN;
        END

        INSERT INTO SANPHAM
        (MASP, TENSANPHAM, DONGIA, MOTASP, TONKHO, SOLUONGTOIDA, MADM, MANSX)
        VALUES
        (@MASP, @TENSP, @DONGIA, @MOTASP, @TONKHO, @SOLUONGTOIDA, @MADM, @NHASANXUAT);


        COMMIT TRAN;

        PRINT N'Thêm sản phẩm thành công.';
    END TRY

    BEGIN CATCH
        ROLLBACK TRAN;
        PRINT N'Lỗi khi thêm sản phẩm.';
    END CATCH
END
GO