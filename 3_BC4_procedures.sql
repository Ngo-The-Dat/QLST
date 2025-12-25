USE QLST
GO
--1
CREATE OR ALTER PROCEDURE USP_ADD_SAN_PHAM_TO_KHUYEN_MAI
    @MAKM VARCHAR(10),
    @MASP VARCHAR(10),
    @SOLUONG INT,
    @TILEGIAM FLOAT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @TONKHOHIENTAI INT, @TONGSLKHUYENMAIDAGAN INT

	SELECT @TONKHOHIENTAI = TONKHO
	FROM SANPHAM
	WHERE MASP = @MASP

	SELECT @TONGSLKHUYENMAIDAGAN = SUM(SOLUONG)
	FROM CHITIETKM
	WHERE MASP = @MASP

	-- 1. Kiểm tra ràng buộc về tỉ lệ giảm giá
	IF @TILEGIAM <= 0 OR @TILEGIAM >= 1
	BEGIN
		RAISERROR(N'Tỷ lệ giảm giá không hợp lệ', 16, 1)
		RETURN
	END

	-- 2. Kiểm tra tồn tại và hiệu lực của KM
	IF NOT EXISTS(
		SELECT *
		FROM KHUYENMAI
		WHERE @MAKM = MAKM AND NGAYKETTHUC >= GETDATE()
	)
	BEGIN
		RAISERROR(N'Chương trình khuyến mãi không tồn tại hoặc đã kết thúc', 16, 1)
		RETURN
	END

	-- 3. Kiểm tra tồn kho và tổng số lượng khuyến mãi
	IF (@TONGSLKHUYENMAIDAGAN + @SOLUONG >= @TONKHOHIENTAI)
	BEGIN
		DECLARE @ERRORMSG VARCHAR(200);
		SET @ERRORMSG = N'Không hợp lệ! Tổng số lượng khuyến mãi(' + CAST(@TONGSLKHUYENMAIDAGAN + @SOLUONG AS VARCHAR) + N') vượt quá số tồn kho hiện tại(' + CAST(@TONKHOHIENTAI AS VARCHAR) + N')'
		RAISERROR(@ERRORMSG, 16, 1)
		RETURN
	END

	-- 4. Thực hiện insert
	BEGIN TRY
		BEGIN TRANSACTION
		IF EXISTS(SELECT 1 FROM CHITIETKM WHERE MAKM = @MAKM AND MASP = @MASP)
			UPDATE CHITIETKM 
			SET SOLUONG += @SOLUONG,
				TILEGIAM = @TILEGIAM
			WHERE MAKM = @MAKM AND MASP = @MASP
		ELSE
			INSERT INTO CHITIETKM (MASP, MAKM, SOLUONG, TILEGIAM)
			VALUES (@MASP, @MAKM, @SOLUONG, @TILEGIAM)
		
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN
		THROW
	END CATCH
END
GO
--2
CREATE OR ALTER PROCEDURE USP_ADD_THANH_VIEN
    @MANV VARCHAR(10),
    @HOTEN NVARCHAR(50),
    @SDT VARCHAR(10),
    @DIACHI NVARCHAR(100),
    @NGAYSINH DATE
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	-- 1. VALIDATION --
	-- KIỂM TRA NHÂN VIÊN TỒN TẠI HAY KHÔNG
	IF NOT EXISTS(SELECT 1 FROM NHANVIEN WHERE MANV = @MANV)
	BEGIN
        RAISERROR(N'Mã nhân viên không hợp lệ.', 16, 1);
        RETURN;
    END
	-- KIỂM TRA SĐT ĐÃ TỒN TẠI CHƯA
	IF EXISTS(SELECT 1 FROM KHACHHANG WHERE SDT = @SDT)
	BEGIN
		RAISERROR(N'Số điện thoại đã tồn tại', 16, 1)
		RETURN
	END
	-- KIỂM TRA NGÀY SINH HỢP LỆ KHÔNG
	IF @NGAYSINH >= GETDATE()
	BEGIN
        RAISERROR(N'Ngày sinh không được lớn hơn hoặc bằng ngày hiện tại.', 16, 1);
        RETURN;
    END
	
	BEGIN TRY
		BEGIN TRAN
			-- 2. TẠO MAKH
			DECLARE @MAX INT
			DECLARE @MAKH VARCHAR(10)
			
			SELECT TOP 1 @MAX = CAST(SUBSTRING(MAKH, 3, LEN(MAKH)) AS INT)
			FROM KHACHHANG WITH (UPDLOCK, HOLDLOCK)
			ORDER BY LEN(MAKH) DESC, MAKH DESC

			SET @MAX = ISNULL(@MAX, 0) + 1
			SET @MAKH = 'KH' + RIGHT('00' + CAST(@MAX AS VARCHAR(10)), 2)
			-- 3. INSERT VAO KHACHHANG
			INSERT INTO KHACHHANG (MAKH, HOTEN, SDT, DIACHI, ISTHANHVIEN)
			VALUES (@MAKH, @HOTEN, @SDT, @DIACHI, 1)
			-- 4. INSERT VAO KH_THANHVIEN
			INSERT INTO KH_THANHVIEN (MAKH, NGAYDANGKY, NGAYSINH, MANV, MACAPDO)
			VALUES (@MAKH, GETDATE(), @NGAYSINH, @MANV, 'LV1')

		COMMIT TRAN
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN
		THROW
	END CATCH
END
GO
--3
-- Tạo kiểu dữ liệu cho các sản phẩm trong hóa đơn
IF NOT EXISTS(SELECT * FROM SYS.types WHERE name = 'CART_ITEM')
	CREATE TYPE CART_ITEM AS TABLE
	(
		MASP VARCHAR(10),
		SOLUONG INT
	)
GO

CREATE OR ALTER PROCEDURE USP_PROCESS_NEW_ORDER
    @MANV VARCHAR(10),
    @MAKH VARCHAR(10),
    @MAPG VARCHAR(10),
    @Cart_Items CART_ITEM READONLY
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON
	
	BEGIN TRY
		BEGIN TRAN
			-- Sort lại thứ tự sản phẩm để tránh deadlock khi read @Cart_Items(A,B) và (B,A)
			DECLARE @SORTED_CART CART_ITEM
			INSERT INTO @SORTED_CART
			SELECT *
			FROM @Cart_Items
			ORDER BY MASP ASC

			-- 1. VALIDATION CƠ BẢN --
			-- Kiểm tra nhân viên có tồn tại không
			IF NOT EXISTS (SELECT 1 FROM NHANVIEN WHERE MANV = @MANV)
				THROW 50001, N'Nhân viên không tồn tại', 1
			-- Kiểm tra tồn kho sản phẩm
			IF EXISTS(
				SELECT 1
				FROM @SORTED_CART C 
				JOIN SANPHAM S WITH(UPDLOCK, HOLDLOCK) ON C.MASP = S.MASP
				WHERE C.SOLUONG > S.TONKHO
			)
				THROW 50002, N'Một số sản phẩm không đủ tồn kho', 1

			-- Kiểm tra phiếu giảm giá
			DECLARE @PHANTRAMGIAMVOUCHER FLOAT = 0
			IF @MAPG IS NOT NULL 
			BEGIN
				SELECT @PHANTRAMGIAMVOUCHER = PHANTRAMGIAM
				FROM PHIEUGIAMGIA WITH(UPDLOCK)
				WHERE @MAPG = MAPG AND TRANGTHAI = N'Chưa dùng'

				IF @PHANTRAMGIAMVOUCHER IS NULL
					THROW 50003, N'Phiếu giảm giá không hợp lệ hoặc đã sử dụng', 1
			END
		
			-- Lấy thông tin khách hàng và cấp độ thẻ(nếu có)
			DECLARE @ISMEMBER BIT = 0
			DECLARE @MACAPDO VARCHAR(10) = NULL

			SELECT @ISMEMBER = 1, @MACAPDO = MACAPDO
			FROM KH_THANHVIEN
			WHERE MAKH = @MAKH

			-- 2. Tạo hóa đơn --
			DECLARE @MAHD VARCHAR(10)
			DECLARE @LASTID INT

			SELECT TOP 1 @LASTID = CAST(SUBSTRING(MAHD, 3, LEN(MAHD)) AS INT)
			FROM HOADON WITH (UPDLOCK, HOLDLOCK)
			ORDER BY LEN(MAHD) DESC, MAHD DESC
	
			SET @LASTID = ISNULL(@LASTID, 0) + 1
			SET @MAHD = 'HD' + RIGHT('00' + CAST(@LASTID AS VARCHAR(10)), 2)
			-- Thêm dữ liệu tạm thời vào hóa đơn
			INSERT INTO HOADON(MAHD, NGAYLAP, TONGTIEN, MANV, MAPG, MAKH)
			VALUES (@MAHD, GETDATE(), 0, @MANV, @MAPG, @MAKH)

			-- 3. XỬ LÝ CHI TIẾT & TÍNH TOÁN KHUYẾN MÃI --
			-- SỬ DỤNG BẢNG PHỤ ĐỂ TÍNH TOÁN TRƯỚC KHI INSERT
			DECLARE @TEMPDETAILS TABLE
			(
				MASP VARCHAR(10),
				SOLUONG INT,
				DONGIA INT,
				MAKM VARCHAR(10),
				TILEGIAM FLOAT,
				SL_DUOC_GIAM INT, --MAX = 3
				THANHTIEN INT
			)

			INSERT INTO @TEMPDETAILS (MASP, SOLUONG, DONGIA, MAKM, TILEGIAM, SL_DUOC_GIAM, THANHTIEN)
			SELECT 
				C.MASP,
				C.SOLUONG,
				S.DONGIA,
				BESTKM.MAKM, -- LẤY TỪ OUTER APPLY
				ISNULL(BESTKM.TILEGIAM, 0), -- LẤY TỪ OUTER APPLY
				-- LOGIC TÍNH SỐ LƯỢNG ĐƯỢC GIẢM
				CASE
					WHEN BESTKM.MAKM IS NOT NULL THEN
						CASE WHEN C.SOLUONG > 3 THEN 3 ELSE C.SOLUONG END
					ELSE 0
				END AS SL_DUOC_GIAM,
				-- LOGIC TÍNH THÀNH TIỀN
				-- (Số lượng được giảm * Giá giảm) + (Số lượng vượt quá * Giá gốc)
				CAST (
					(
						CASE
							WHEN BESTKM.MAKM IS NOT NULL THEN
								(CASE WHEN C.SOLUONG > 3 THEN 3 ELSE C.SOLUONG END) * S.DONGIA * (1 - ISNULL(BESTKM.TILEGIAM, 0))
							ELSE 0
						END
					)
					+
					(
						CASE
							WHEN BESTKM.MAKM IS NOT NULL AND C.SOLUONG > 3 THEN (C.SOLUONG - 3) * S.DONGIA
							WHEN BESTKM.MAKM IS NULL THEN C.SOLUONG * S.DONGIA
							ELSE 0
						END
					)
					AS INT
				) AS THANHTIEN 

			FROM @SORTED_CART C
			JOIN SANPHAM S ON C.MASP = S.MASP
			-- Tìm khuyến mãi hợp lệ nhất
			OUTER APPLY (
				SELECT TOP 1 CT.MAKM, CT.TILEGIAM
				FROM CHITIETKM CT WITH(UPDLOCK)
				JOIN KHUYENMAI KM ON CT.MAKM = KM.MAKM
				WHERE CT.MASP = S.MASP
				AND KM.NGAYBATDAU <= GETDATE()
				AND KM.NGAYKETTHUC >= GETDATE()
				AND CT.SOLUONG > 0 -- SỐ LƯỢNG KHUYẾN MÃI ĐANG CÒN
				AND (
					-- Loại 1: FLASH SALE(ISMEMBER = 0) - ĐỘ ƯU TIÊN CAO NHẤT
					KM.ISMEMBER = 0
					OR
					-- Loại 2: MEMBER SALE(ISMEMBER = 1) -- ĐỘ ƯU TIÊN THẤP HƠN, CHỈ ÁP DỤNG CHO THÀNH VIÊN
					(
						KM.ISMEMBER = 1
						AND @ISMEMBER = 1
						AND EXISTS (SELECT 1 FROM MEMBER_SALE MS WHERE MS.MAKM = KM.MAKM AND MS.MACAPDO = @MACAPDO)
					)
				)
				-- SẮP XẾP THEO ĐỘ ƯU TIÊN
				-- FLASH SALE(ISMEMBER = 0) ƯU TIÊN HƠN MEMBER SALE(ISMEMBER = 1)
				ORDER BY KM.ISMEMBER ASC, CT.TILEGIAM DESC
			) AS BESTKM
			-- Insert vào bảng chính thức
			INSERT INTO CHITIETHOADON (MAHD, MASP, SOLUONG, THANHTIEN, MAKM)
			SELECT @MAHD, MASP, SOLUONG, THANHTIEN, MAKM
			FROM @TEMPDETAILS

			-- 4. Trừ tồn kho sản phẩm --
			UPDATE S
			SET	S.TONKHO -= C.SOLUONG
			FROM SANPHAM S
			JOIN @SORTED_CART C ON C.MASP = S.MASP

			-- 5. Trừ số lượng khuyến mãi --
			UPDATE CT
			SET CT.SOLUONG -= T.SL_DUOC_GIAM
			FROM CHITIETKM CT
			JOIN @TEMPDETAILS T ON CT.MASP = T.MASP AND CT.MAKM = T.MAKM
			WHERE T.MAKM IS NOT NULL AND T.SL_DUOC_GIAM > 0

			-- 6. Cập nhật tổng tiền hóa đơn & voucher --
			DECLARE @TONGTIEN INT = 0
			SELECT @TONGTIEN = SUM(THANHTIEN)
			FROM CHITIETHOADON CT
			WHERE CT.MAHD = @MAHD

			UPDATE HOADON
			SET TONGTIEN = CAST(@TONGTIEN * (1 - @PHANTRAMGIAMVOUCHER) AS INT)
			WHERE MAHD = @MAHD

			IF @MAPG IS NOT NULL
				UPDATE PHIEUGIAMGIA SET TRANGTHAI = N'Đã dùng' WHERE MAPG = @MAPG
		COMMIT TRAN
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN
		THROW
	END CATCH
END
GO
--4
CREATE OR ALTER PROCEDURE USP_ADD_KHUYEN_MAI
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
--5
CREATE OR ALTER PROCEDURE USP_CANCEL_ORDER 
    @mahd varchar(10)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION
        IF NOT EXISTS (SELECT 1 FROM HOADON WHERE MAHD = @mahd)
        BEGIN
            PRINT N'Hóa đơn không tồn tại'
            ROLLBACK TRANSACTION
            RETURN
        END

        DECLARE @cur_masp varchar(10), @cur_soluong int, @cur_makm varchar(10)
        DECLARE @makh varchar(10), @mapg varchar(10)

        SELECT @makh = MAKH, @mapg = MAPG FROM HOADON WHERE MAHD = @mahd

        IF @mapg IS NOT NULL
        BEGIN
            UPDATE PHIEUGIAMGIA SET TRANGTHAI = N'Chưa dùng' WHERE MAPG = @mapg;
        END

        DECLARE cur_chitietdon CURSOR LOCAL FOR 
            SELECT MASP, SOLUONG, MAKM 
            FROM CHITIETHOADON 
            WHERE MAHD = @mahd
            ORDER BY MASP; -- giải quyết deadlock
        
        OPEN cur_chitietdon
        FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @sl_tonkho_hientai int, @sl_tonkho_toida int
            SELECT @sl_tonkho_hientai = tonkho, @sl_tonkho_toida = SOLUONGTOIDA 
            FROM SANPHAM WITH (UPDLOCK)  -- giải quyết lost update, unrepeatable read
            WHERE masp = @cur_masp

            IF @cur_makm IS NOT NULL
            BEGIN
                DECLARE @Sl_Hoan_KM INT = CASE WHEN @cur_soluong > 3 THEN 3 ELSE @cur_soluong END;
                UPDATE CHITIETKM 
                SET SOLUONG = SOLUONG + @Sl_Hoan_KM
                WHERE MAKM = @cur_makm AND MASP = @cur_masp;
            END

            DECLARE @SL_tonkho_saucapnhat int = @sl_tonkho_hientai + @cur_soluong
            IF @SL_tonkho_saucapnhat > @sl_tonkho_toida 
            BEGIN
                RAISERROR(N'Vượt quá tồn kho tối đa khi hoàn hàng', 16, 1)
                ROLLBACK TRANSACTION
                RETURN
            END

            UPDATE SANPHAM SET TONKHO = @SL_tonkho_saucapnhat WHERE MASP = @cur_masp;
            
            FETCH NEXT FROM cur_chitietdon INTO @cur_masp, @cur_soluong, @cur_makm
        END
        
        CLOSE cur_chitietdon
        DEALLOCATE cur_chitietdon

        DELETE FROM CHITIETHOADON WHERE MAHD = @mahd;
        DELETE FROM HOADON WHERE MAHD = @mahd; 

        COMMIT TRANSACTION
        PRINT N'Hủy đơn hàng thành công.'
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO
--6
IF TYPE_ID(N'RECEIVED_ITEM') IS NULL
BEGIN
    CREATE TYPE RECEIVED_ITEM AS TABLE
    (
        MAHD VARCHAR(10),    
        SLNHANTHUCTE INT
    )
END
GO
CREATE OR ALTER PROCEDURE USP_RECEIVE_GOODS_FROM_NSX 
    @v_received_items RECEIVED_ITEM READONLY
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION 
        
        DECLARE @MAPN varchar(10), @MANSX varchar(10)
        DECLARE @Cur_MAHD varchar(10), @Cur_SL int, @Cur_MASP VARCHAR(10);

        SELECT TOP 1 @MANSX = SP.MANSX
        FROM @v_received_items L
        JOIN DONDATHANG DDH ON L.MAHD = DDH.MAHD
        JOIN SANPHAM SP ON DDH.MASP = SP.MASP;

        SET @MAPN = 'PN' + LEFT(REPLACE(CAST(NEWID() AS VARCHAR(50)), '-', ''), 8);
        INSERT INTO PHIEUNHAPHANG (MAPN, MANSX) VALUES (@MAPN, @MANSX);

        DECLARE cur_HangNhap CURSOR LOCAL FOR 
            SELECT MAHD, SLNHANTHUCTE 
            FROM @v_received_items
            ORDER BY MAHD; -- giải quyết Deadlock

        OPEN cur_HangNhap;
        FETCH NEXT FROM cur_HangNhap INTO @Cur_MAHD, @Cur_SL;

        WHILE @@FETCH_STATUS = 0 
        BEGIN
            DECLARE @sldanhan int, @sldat int
            SELECT @sldat = SOLUONGDAT, @sldanhan = SOLUONGDANHAN, @Cur_MASP = MASP  
            FROM DONDATHANG WITH (UPDLOCK) -- giải quyết lost update, unrepeatable read
            WHERE mahd = @Cur_MAHD

            DECLARE @tonkhohientai INT, @soluongtoida int
            SELECT @tonkhohientai = TONKHO, @soluongtoida = soluongtoida  
            FROM SANPHAM WITH (UPDLOCK) -- giải quyết lost update, unrepeatable read
            WHERE masp = @Cur_MASP
            --Print @sldat 
            --Print @tonkhohientai
            --print @sldanhan
            IF @sldanhan + @Cur_SL > @sldat
            BEGIN
                RAISERROR(N'Số lượng nhập hàng vượt quá yêu cầu đặt', 16, 1);
                ROLLBACK TRAN; RETURN;
            END

            DECLARE @tonkhosaucapnhat int = @tonkhohientai + @Cur_SL
            IF @tonkhosaucapnhat > @soluongtoida 
            BEGIN
                RAISERROR(N'Số lượng nhập hàng vượt số lượng tối đa của sản phẩm', 16, 1);
                ROLLBACK TRAN; RETURN;
            END
            --WAITFOR DELAY '00:00:05'
            --SELECT @sldat = SOLUONGDAT, @sldanhan = SOLUONGDANHAN, @Cur_MASP = MASP  
            --FROM DONDATHANG-- WITH (UPDLOCK) -- giải quyết lost update, unrepeatable read
            --WHERE mahd = @Cur_MAHD
            --SELECT @tonkhohientai = TONKHO, @soluongtoida = soluongtoida  
            --FROM SANPHAM --WITH (UPDLOCK) -- giải quyết lost update, unrepeatable read
            --WHERE masp = @Cur_MASP
            --Print @sldat 
            --Print @tonkhohientai
            --print @sldanhan
            UPDATE DONDATHANG
            SET SOLUONGDANHAN = SOLUONGDANHAN + @Cur_SL,
                trangthai = CASE WHEN SOLUONGDANHAN + @Cur_SL = @sldat THEN N'Đã giao đủ' ELSE N'Đã giao một phần' END
            WHERE mahd = @Cur_MAHD

            INSERT INTO CHITIETPHIEUNHAP(MAHD, MAPN, SLNHANTHUCTE) VALUES (@Cur_MAHD, @MAPN, @Cur_SL);

            UPDATE SANPHAM SET TONKHO = @tonkhosaucapnhat WHERE MASP = @Cur_MASP;

            FETCH NEXT FROM cur_HangNhap INTO @Cur_MAHD, @Cur_SL;
        END

        CLOSE cur_HangNhap;
        DEALLOCATE cur_HangNhap;
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO

--7
CREATE OR ALTER PROCEDURE USP_REPORT_LOW_STOCK_ITEMS
    @TY_LE_CANH_BAO FLOAT = 0.7
AS
BEGIN
    SET NOCOUNT ON;

    IF @TY_LE_CANH_BAO <= 0 OR @TY_LE_CANH_BAO > 1
    BEGIN
        PRINT N'Lỗi: Tỷ lệ cảnh báo phải trong khoảng (0, 1]';
        RETURN;
    END

    BEGIN TRY
       
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        BEGIN TRANSACTION;

        -- Đọc nhanh và snapshot vào bảng tạm
        SELECT 
            MASP,
            TENSANPHAM,
            TONKHO,
            SOLUONGTOIDA,
            CAST(TONKHO AS FLOAT) / SOLUONGTOIDA AS TY_LE_TON_KHO
        INTO #TempLowStock
        FROM SANPHAM WITH (NOLOCK)  -- Chấp nhận dirty read để đọc nhanh
        WHERE SOLUONGTOIDA > 0
          AND (CAST(TONKHO AS FLOAT) / SOLUONGTOIDA) < @TY_LE_CANH_BAO;

        COMMIT TRANSACTION;

        DECLARE @SoLuongSanPham INT;
        SELECT @SoLuongSanPham = COUNT(*) FROM #TempLowStock;
        PRINT N'Tỷ lệ cảnh báo: ' + CAST(@TY_LE_CANH_BAO * 100 AS NVARCHAR) + N'%';
        PRINT N'Số lượng SP cảnh báo: ' + CAST(@SoLuongSanPham AS NVARCHAR);
        PRINT N'';

        SELECT 
            MASP,
            TENSANPHAM,
            TONKHO,
            SOLUONGTOIDA,
            CAST(ROUND(TY_LE_TON_KHO * 100, 2) AS DECIMAL(5,2)) AS TY_LE_TON_KHO_PHAN_TRAM
        FROM #TempLowStock
        ORDER BY TY_LE_TON_KHO ASC;

        DROP TABLE #TempLowStock;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF OBJECT_ID('tempdb..#TempLowStock') IS NOT NULL
            DROP TABLE #TempLowStock;
        
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT N'Lỗi: ' + @ErrMsg;
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO
--8
CREATE OR ALTER PROCEDURE USP_REPORT_PRODUCT_SALES_BY_DAY
    @NGAY DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- Dùng REPEATABLE READ
        SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        BEGIN TRANSACTION;

        DECLARE @TongSoKhachHang INT;
        DECLARE @TongDoanhThu BIGINT;

        -- Đọc tất cả dữ liệu cần thiết một lần với HOLDLOCK
        SELECT @TongSoKhachHang = COUNT(DISTINCT MAKH)
        FROM HOADON WITH (HOLDLOCK)
        WHERE CAST(NGAYLAP AS DATE) = @NGAY;

        SELECT @TongDoanhThu = ISNULL(SUM(TONGTIEN), 0)
        FROM HOADON WITH (HOLDLOCK)
        WHERE CAST(NGAYLAP AS DATE) = @NGAY;


        SELECT 
            SP.MASP,
            SP.TENSANPHAM,
            SUM(CTHD.SOLUONG) AS TONG_SO_LUONG_BAN,
            COUNT(DISTINCT HD.MAKH) AS SO_LUONG_KHACH_HANG_MUA
        INTO #TempProductSales
        FROM HOADON HD WITH (HOLDLOCK)
        JOIN CHITIETHOADON CTHD WITH (HOLDLOCK) ON HD.MAHD = CTHD.MAHD
        JOIN SANPHAM SP ON CTHD.MASP = SP.MASP
        WHERE CAST(HD.NGAYLAP AS DATE) = @NGAY
        GROUP BY SP.MASP, SP.TENSANPHAM;

        COMMIT TRANSACTION;

        -- Xử lý và hiển thị kết quả từ temp table (không còn lock)
        PRINT N'Tổng số khách hàng: ' + CAST(@TongSoKhachHang AS NVARCHAR);
        PRINT N'Tổng doanh thu: ' + FORMAT(@TongDoanhThu, 'N0') + N' VNĐ';
        PRINT N'';

        SELECT 
            @NGAY AS NGAY_BAO_CAO,
            @TongSoKhachHang AS TONG_SO_KHACH_HANG,
            @TongDoanhThu AS TONG_DOANH_THU;

        PRINT N'Chi tiết sản phẩm:';
        SELECT 
            MASP,
            TENSANPHAM,
            TONG_SO_LUONG_BAN,
            SO_LUONG_KHACH_HANG_MUA
        FROM #TempProductSales
        ORDER BY TONG_SO_LUONG_BAN DESC;

        DROP TABLE #TempProductSales;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF OBJECT_ID('tempdb..#TempProductSales') IS NOT NULL
            DROP TABLE #TempProductSales;
        
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT N'Lỗi: ' + @ErrMsg;
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO
--9
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
--10
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
--11
CREATE OR ALTER PROCEDURE USP_PROCESS_STOCK_REORDERING
    @MANV VARCHAR(10)
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

	IF NOT EXISTS (SELECT * FROM NHANVIEN WHERE @MANV = MANV)
	BEGIN
		PRINT N'Nhân viên không tồn tại'
		RETURN
	END
	ELSE
	IF (SELECT VAITRO FROM NHANVIEN WHERE @MANV = MANV) <> N'Quản lý kho hàng'
	BEGIN
		PRINT N'Nhân viên không thuộc bộ phận Quản lý kho hàng'
		RETURN
	END

    DECLARE curSP CURSOR FOR
        SELECT MASP, TONKHO, SOLUONGTOIDA
        FROM SANPHAM;

    DECLARE 
        @MASP VARCHAR(10),
        @TONKHO INT,
        @SLMAX INT,
        @NGUONG70 INT,
        @SLDangDat INT,
        @SLCanDat INT,
        @SLToiThieu INT,
        @LastID INT,
        @NewID VARCHAR(10);

    -- Table tạm để trả kết quả
    DECLARE @RESULT TABLE (MASP VARCHAR(10), SOLUONGDAT INT);

    OPEN curSP;
    FETCH NEXT FROM curSP INTO @MASP, @TONKHO, @SLMAX;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRAN;

            -- Tính ngưỡng 70%
            SET @NGUONG70 = (@SLMAX * 70) / 100;

            IF @TONKHO < @NGUONG70
            BEGIN
                -- Đọc số lượng đã đặt nhưng chưa giao
                SELECT @SLDangDat = ISNULL(SUM(SOLUONGDAT - SOLUONGDANHAN), 0)
                FROM DONDATHANG
                WHERE MASP = @MASP;

                -- Tính số lượng cần đặt
                SET @SLCanDat = @NGUONG70 - (@TONKHO + @SLDangDat);

                -- Số lượng tối thiểu = 10%
                SET @SLToiThieu = (@SLMAX * 10) / 100;

                IF @SLCanDat >= @SLToiThieu
                BEGIN
                    -- Lấy mã đơn đặt hàng mới nhất
                    SELECT @LastID = MAX(CAST(SUBSTRING(MAHD, 4, 2) AS INT))
					FROM DONDATHANG;
					
					IF @LastID IS NULL
					BEGIN
					    SET @NewID = 'DDH01';
					END
					ELSE
					BEGIN
					    SET @NewID = 'DDH' + RIGHT('0' + CAST(@LastID + 1 AS VARCHAR(10)), 2);
					END

                    -- Tạo đơn đặt hàng mới
                    INSERT INTO DONDATHANG
                    (MAHD, NGAYLAP, SOLUONGDAT, SOLUONGDANHAN, TRANGTHAI, MANV, MASP)
                    VALUES
                    (@NewID, GETDATE(), @SLCanDat, 0, N'Chưa giao', @MANV, @MASP);

                    -- Lưu kết quả
                    INSERT INTO @RESULT VALUES(@MASP, @SLCanDat);
                END
            END

            COMMIT TRAN;
        END TRY
        BEGIN CATCH
            ROLLBACK TRAN;
            PRINT N'Lỗi xảy ra khi xử lý sản phẩm ' + @MASP;
        END CATCH;

        FETCH NEXT FROM curSP INTO @MASP, @TONKHO, @SLMAX;
    END

    CLOSE curSP;
    DEALLOCATE curSP;

    -- Trả kết quả đặt hàng
    SELECT * FROM @RESULT;
END
GO
--12
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
--13
-- Bộ phận quản lý kho hàng
CREATE OR ALTER PROCEDURE USP_CANCEL_DAT_HANG
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

        -- Cập nhật thêm số lượng đã nhận hoặc trạng thái

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
--14
CREATE OR ALTER PROCEDURE USP_REPORT_DAILY_SUMMARY
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    BEGIN TRANSACTION
    BEGIN TRY

        DECLARE 
        @CurrentDate DATE = GETDATE();

        DECLARE @TongKH INT;
        DECLARE @TongDT BIGINT;

        SELECT 
            @TongKH = ISNULL(COUNT(DISTINCT MAKH),0),
            @TongDT = ISNULL(SUM(TONGTIEN), 0)
        FROM HOADON
        WHERE NGAYLAP = CAST(@CurrentDate AS DATE);

        -- Conflict nếu insert  dòng hóa đơn

        SELECT 
            N'Báo Cáo Ngày' AS TieuDe,
            @CurrentDate AS Ngay,
            @TongKH AS TongKhachHang,
            FORMAT(@TongDT, '#,##0') + ' VND' AS TongDoanhThu;

        SELECT 
            SP.MASP, 
            SP.TENSANPHAM, 
            SUM(CTHD.SOLUONG) AS SoLuongBan, 
            COUNT(DISTINCT HD.MAKH) AS SoKhachMua,
            FORMAT(SUM(CTHD.THANHTIEN), '#,##0') AS DoanhThuSanPham
        FROM SANPHAM SP
        JOIN CHITIETHOADON CTHD ON CTHD.MASP = SP.MASP
        JOIN HOADON HD ON CTHD.MAHD = HD.MAHD
        WHERE HD.NGAYLAP = CAST(@CurrentDate AS DATE)
        GROUP BY SP.MASP, SP.TENSANPHAM
        ORDER BY SoLuongBan DESC;
        COMMIT TRANSACTION

    END TRY

    BEGIN CATCH
        ROLLBACK TRANSACTION
        DECLARE @error NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@error, 16, 1)
    END CATCH
END
GO
--15
CREATE OR ALTER PROCEDURE USP_RUN_MONTHLY_CUSTOMER_UPDATE
    @SoLuongThanhVienCapNhat INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @CurrentDate DATE = GETDATE();
        DECLARE @CurrentYear INT = YEAR(@CurrentDate);
        DECLARE @CurrentMonth INT = MONTH(@CurrentDate);

        -- CẬP NHẬT CẤP ĐỘ THẺ
        DECLARE @TongTienKH TABLE (
            MAKH VARCHAR(10),
            TONGTIEN INT
        );

        INSERT INTO @TongTienKH(MAKH, TONGTIEN)
        SELECT MAKH, SUM(SOTIENDATIEU)
        FROM SOTIENTIEU
        WHERE @CurrentYear - NAM <= 1
        GROUP BY MAKH

        UPDATE KHTV
        SET MACAPDO = (
            SELECT TOP 1 CD.MACAPDO
            FROM CAPDOTHE CD
            WHERE TT.TONGTIEN >= CD.TONGTIENTOITHIEU
            ORDER BY CD.TONGTIENTOITHIEU DESC
        )
        FROM KH_THANHVIEN KHTV
        JOIN @TongTienKH TT ON KHTV.MAKH = TT.MAKH;

        SET @SoLuongThanhVienCapNhat = @@ROWCOUNT;

        -- TẶNG PHIẾU GIẢM GIÁ SINH NHẬT
        DECLARE @MaxCurrentId INT;
        SELECT @MaxCurrentId = ISNULL(MAX(CAST(RIGHT(MAPG, 8) AS INT)), 0)
        FROM PHIEUGIAMGIA 
        WHERE MAPG LIKE 'PG[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]';
        
        INSERT INTO PHIEUGIAMGIA(MAPG, PHANTRAMGIAM, TRANGTHAI, MAKH)
        SELECT
            -- GEMINI CHỈ
            'PG' + RIGHT('00000000' + CAST(@MaxCurrentId + ROW_NUMBER() OVER(ORDER BY MAKH) AS VARCHAR(10)), 8),            
            CD.PHANTRAMGIAMSN,
            N'Chưa dùng',
            KHTV.MAKH
        FROM KH_THANHVIEN KHTV
        JOIN CAPDOTHE CD ON KHTV.MACAPDO = CD.MACAPDO
        WHERE MONTH(KHTV.NGAYSINH) = @CurrentMonth
            AND CD.PHANTRAMGIAMSN > 0
            -- Chống duplicate
            AND NOT EXISTS (
                SELECT 1 FROM PHIEUGIAMGIA PG
                WHERE KHTV.MAKH = PG.MAKH
                AND MONTH(GETDATE()) = @CurrentMonth
            );
        
        COMMIT TRANSACTION;
        PRINT N'Cập nhật khách hàng theo tháng thành công.';

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @error NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@error, 16, 1)
    END CATCH

END;