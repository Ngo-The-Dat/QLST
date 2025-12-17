USE MASTER
GO
IF EXISTS(SELECT *
FROM SYS.DATABASES
WHERE name = 'QLST')
BEGIN
	ALTER DATABASE QLST SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE QLST
END
GO
CREATE DATABASE QLST
GO
USE QLST
GO
----CREATE TABLE----
CREATE TABLE NHANVIEN
(
	MANV VARCHAR(10) PRIMARY KEY,
	HOTEN NVARCHAR(50),
	VAITRO NVARCHAR(50) NOT NULL CHECK(VAITRO IN(N'Chăm sóc khách hàng', N'Quản lý ngành hàng', N'Xử lý đơn hàng', N'Quản lý kho hàng', N'Kinh doanh'))
)

CREATE TABLE KHACHHANG
(
	MAKH VARCHAR(10) PRIMARY KEY,
	HOTEN NVARCHAR(50),
	SDT VARCHAR(10),
	DIACHI NVARCHAR(100),
	ISTHANHVIEN BIT DEFAULT 0
)

CREATE TABLE CAPDOTHE
(
	MACAPDO VARCHAR(10) PRIMARY KEY,
	TENCAPDO NVARCHAR(50) UNIQUE,
	TONGTIENTOITHIEU INT CHECK(TONGTIENTOITHIEU >= 0),
	PHANTRAMGIAMSN FLOAT CHECK(PHANTRAMGIAMSN >= 0)
)

CREATE TABLE KH_THANHVIEN
(
	MAKH VARCHAR(10) PRIMARY KEY,
	NGAYDANGKY DATE,
	NGAYSINH DATE,
	MANV VARCHAR(10),
	MACAPDO VARCHAR(10)

		FOREIGN KEY(MAKH) REFERENCES KHACHHANG(MAKH),
	FOREIGN KEY(MANV) REFERENCES NHANVIEN(MANV),
	FOREIGN KEY(MACAPDO) REFERENCES CAPDOTHE(MACAPDO),
	CHECK(NGAYDANGKY > NGAYSINH)
)

CREATE TABLE PHIEUGIAMGIA
(
	MAPG VARCHAR(10) PRIMARY KEY,
	PHANTRAMGIAM FLOAT CHECK(PHANTRAMGIAM > 0),
	TRANGTHAI NVARCHAR(10) NOT NULL CHECK(TRANGTHAI IN(N'Đã dùng', N'Chưa dùng')),
	MAKH VARCHAR(10)

		FOREIGN KEY(MAKH) REFERENCES KH_THANHVIEN(MAKH)
)

CREATE TABLE SOTIENTIEU
(
	MAKH VARCHAR(10),
	NAM INT CHECK(NAM > 0),
	SOTIENDATIEU INT CHECK(SOTIENDATIEU >= 0) DEFAULT 0

		PRIMARY KEY(MAKH,NAM)
		FOREIGN KEY(MAKH) REFERENCES KH_THANHVIEN(MAKH)
)

CREATE TABLE KHUYENMAI
(
	MAKM VARCHAR(10) PRIMARY KEY,
	NGAYBATDAU DATE,
	NGAYKETTHUC DATE,
	MANV VARCHAR(10),
	ISMEMBER BIT

		FOREIGN KEY (MANV) REFERENCES NHANVIEN(MANV),
	CHECK(NGAYKETTHUC >= NGAYBATDAU)
)

CREATE TABLE MEMBER_SALE
(
	MAKM VARCHAR(10),
	MACAPDO VARCHAR(10)

		PRIMARY KEY(MAKM, MACAPDO)
		FOREIGN KEY(MAKM) REFERENCES KHUYENMAI(MAKM),
	FOREIGN KEY(MACAPDO) REFERENCES CAPDOTHE(MACAPDO)
)

CREATE TABLE DANHMUC
(
	MADM VARCHAR(10) PRIMARY KEY,
	CHUNGLOAI NVARCHAR(50) UNIQUE,
	MANV VARCHAR(10)

		FOREIGN KEY(MANV) REFERENCES NHANVIEN(MANV)
)

CREATE TABLE NHASANXUAT
(
	MANSX VARCHAR(10) PRIMARY KEY,
	TENNSX NVARCHAR(50),
	DIACHI NVARCHAR(100),
	EMAIL VARCHAR(50) UNIQUE,
	SDT VARCHAR(10)
)

CREATE TABLE SANPHAM
(
	MASP VARCHAR(10) PRIMARY KEY,
	TENSANPHAM NVARCHAR(50),
	DONGIA INT CHECK(DONGIA > 0),
	MOTASP NVARCHAR(MAX),
	TONKHO INT DEFAULT 0,
	SOLUONGTOIDA INT CHECK(SOLUONGTOIDA > 0),
	MADM VARCHAR(10),
	MANSX VARCHAR(10)

		FOREIGN KEY(MADM) REFERENCES DANHMUC(MADM),
	FOREIGN KEY(MANSX) REFERENCES NHASANXUAT(MANSX),
	CHECK(TONKHO <= SOLUONGTOIDA)
)

CREATE TABLE CHITIETKM
(
	MASP VARCHAR(10),
	MAKM VARCHAR(10),
	SOLUONG INT CHECK(SOLUONG > 0),
	TILEGIAM FLOAT CHECK(TILEGIAM > 0 AND TILEGIAM <= 1)

		PRIMARY KEY(MASP, MAKM),
	FOREIGN KEY(MASP) REFERENCES SANPHAM(MASP),
	FOREIGN KEY(MAKM) REFERENCES KHUYENMAI(MAKM)
)

CREATE TABLE HOADON
(
	MAHD VARCHAR(10) PRIMARY KEY,
	NGAYLAP DATE DEFAULT GETDATE(),
	TONGTIEN INT CHECK(TONGTIEN >= 0) DEFAULT 0,
	MANV VARCHAR(10),
	MAPG VARCHAR(10) NULL,
	MAKH VARCHAR(10)

		FOREIGN KEY(MANV) REFERENCES NHANVIEN(MANV),
	FOREIGN KEY(MAPG) REFERENCES PHIEUGIAMGIA(MAPG),
	FOREIGN KEY(MAKH) REFERENCES KHACHHANG(MAKH)
)

CREATE TABLE CHITIETHOADON
(
	MAHD VARCHAR(10),
	MASP VARCHAR(10),
	SOLUONG INT CHECK(SOLUONG > 0),
	THANHTIEN INT CHECK(THANHTIEN >= 0),
	MAKM VARCHAR(10) NULL

		PRIMARY KEY(MAHD, MASP)
		FOREIGN KEY(MAHD) REFERENCES HOADON(MAHD),
	FOREIGN KEY(MASP) REFERENCES SANPHAM(MASP),
	FOREIGN KEY(MAKM) REFERENCES KHUYENMAI(MAKM)
)

CREATE TABLE DONDATHANG
(
	MAHD VARCHAR(10) PRIMARY KEY,
	NGAYLAP DATE DEFAULT GETDATE(),
	SOLUONGDAT INT CHECK(SOLUONGDAT > 0),
	SOLUONGDANHAN INT CHECK(SOLUONGDANHAN >= 0) DEFAULT 0,
	TRANGTHAI NVARCHAR(30) CHECK(TRANGTHAI IN(N'Chưa giao', N'Đã giao một phần', N'Đã giao đủ')),
	MANV VARCHAR(10),
	MASP VARCHAR(10)

		FOREIGN KEY(MANV) REFERENCES NHANVIEN(MANV),
	FOREIGN KEY(MASP) REFERENCES SANPHAM(MASP),
	CHECK(SOLUONGDANHAN <= SOLUONGDAT)
)

CREATE TABLE PHIEUNHAPHANG
(
	MAPN VARCHAR(10) PRIMARY KEY,
	NGAYNHAP DATE DEFAULT GETDATE(),
	MANSX VARCHAR(10)

		FOREIGN KEY(MANSX) REFERENCES NHASANXUAT(MANSX)
)

CREATE TABLE CHITIETPHIEUNHAP
(
	MAHD VARCHAR(10),
	MAPN VARCHAR(10),
	SLNHANTHUCTE INT CHECK(SLNHANTHUCTE > 0)

		PRIMARY KEY(MAHD, MAPN)
		FOREIGN KEY(MAHD) REFERENCES DONDATHANG(MAHD),
	FOREIGN KEY(MAPN) REFERENCES PHIEUNHAPHANG(MAPN)
)

GO
----EXAMPLE DATA----
-- 1. BẢNG NHANVIEN (Độc lập - Cần có nhân viên trước để quản lý các bảng khác)
INSERT INTO NHANVIEN
	(MANV, HOTEN, VAITRO)
VALUES
	('NV01', N'Nguyễn Minh Hoàng', N'Quản lý ngành hàng'),
	('NV02', N'Trần Tú', N'Quản lý kho hàng'),
	('NV03', N'Lê Văn Công', N'Kinh doanh'),
	('NV04', N'Phạm Thị Bảo Nhi', N'Chăm sóc khách hàng'),
	('NV05', N'Võ Quốc Lý', N'Xử lý đơn hàng'),
	('NV06', N'Hoàng Bảo', N'Quản lý ngành hàng'),
	('NV07', N'Phan Thị Dung', N'Chăm sóc khách hàng'),
	('NV08', N'Ngô Văn Hùng', N'Quản lý kho hàng'),
	('NV09', N'Bùi Minh Tú', N'Xử lý đơn hàng'),
	('NV10', N'Đặng Thị Hoa', N'Kinh doanh');
GO

-- 2. BẢNG KHACHHANG (Độc lập)
INSERT INTO KHACHHANG
	(MAKH, HOTEN, SDT, DIACHI, ISTHANHVIEN)
VALUES
	('KH01', N'Nguyễn Văn A', '0901234567', N'123 Lê Lợi, TP.HCM', 1),
	('KH02', N'Trần Thị B', '0909888777', N'456 Nguyễn Huệ, TP.HCM', 1),
	('KH03', N'Lê Văn C', '0912345678', N'789 Điện Biên Phủ, Hà Nội', 0),
	-- Khách vãng lai
	('KH04', N'Phạm Văn D', '0901111222', N'12 Trần Hưng Đạo, TP.HCM', 1),
	('KH05', N'Nguyễn Thị E', '0902222333', N'34 CMT8, TP.HCM', 1),
	('KH06', N'Trần Văn F', '0903333444', N'56 Lê Lợi, Đà Nẵng', 1),
	('KH07', N'Lê Thị G', '0904444555', N'78 Hai Bà Trưng, Hà Nội', 0),
	('KH08', N'Võ Văn H', '0905555666', N'90 Phan Đình Phùng, Huế', 1),
	('KH09', N'Ngô Thị I', '0906666777', N'11 Nguyễn Trãi, Hải Phòng', 1),
	('KH10', N'Bùi Văn K', '0907777888', N'22 Võ Văn Tần, TP.HCM', 1),
	('KH11', N'Đỗ Thị L', '0908888999', N'33 Trần Phú, Nha Trang', 0),
	('KH12', N'Tạ Văn M', '0910000111', N'44 Nguyễn Văn Cừ, Cần Thơ', 1),
	('KH13', N'Phùng Thị N', '0911111222', N'55 Ngô Quyền, Vinh', 1),
	('KH14', N'Hà Văn O', '0912222333', N'66 Lý Thường Kiệt, Quy Nhơn', 0),
	('KH15', N'Chu Thị P', '0913333444', N'77 Bà Triệu, Bắc Ninh', 1);
GO

-- 3. BẢNG CAPDOTHE (Độc lập)
INSERT INTO CAPDOTHE
	(MACAPDO, TENCAPDO, TONGTIENTOITHIEU, PHANTRAMGIAMSN)
VALUES
	('LV1', N'Đồng', 0, 0),
	('LV2', N'Bạc', 10000000, 0.10),
	('LV3', N'Vàng', 30000000, 0.15),
	('LV4', N'Bạch kim', 50000000, 0.20);
GO

-- 4. BẢNG KH_THANHVIEN (Phụ thuộc: KHACHHANG, NHANVIEN, CAPDOTHE)
-- Lưu ý: NGAYDANGKY phải > NGAYSINH
INSERT INTO KH_THANHVIEN
	(MAKH, NGAYDANGKY, NGAYSINH, MANV, MACAPDO)
VALUES
	('KH01', '2023-01-01', '1995-05-20', 'NV04', 'LV2'),
	('KH02', '2022-06-15', '1990-11-10', 'NV04', 'LV4'),
	('KH04', '2023-02-10', '1992-03-05', 'NV07', 'LV2'),
	('KH05', '2024-01-20', '1994-07-12', 'NV07', 'LV1'),
	('KH06', '2024-03-01', '1991-12-01', 'NV08', 'LV3'),
	('KH08', '2023-05-05', '1988-09-09', 'NV09', 'LV2'),
	('KH09', '2023-06-06', '1990-10-10', 'NV09', 'LV1'),
	('KH10', '2024-02-14', '1993-02-14', 'NV10', 'LV3'),
	('KH12', '2023-11-11', '1985-11-11', 'NV06', 'LV4'),
	('KH13', '2025-01-01', '1996-01-01', 'NV06', 'LV1');
GO

-- 5. BẢNG PHIEUGIAMGIA (Phụ thuộc: KH_THANHVIEN)
INSERT INTO PHIEUGIAMGIA
	(MAPG, PHANTRAMGIAM, TRANGTHAI, MAKH)
VALUES
	('PG01', 0.10, N'Chưa dùng', 'KH01'),
	('PG02', 0.20, N'Đã dùng', 'KH02'),
	('PG03', 0.05, N'Chưa dùng', 'KH04'),
	('PG04', 0.10, N'Chưa dùng', 'KH05'),
	('PG05', 0.15, N'Chưa dùng', 'KH06'),
	('PG06', 0.20, N'Chưa dùng', 'KH08'),
	('PG07', 0.05, N'Đã dùng', 'KH09'),
	('PG08', 0.10, N'Chưa dùng', 'KH10'),
	('PG09', 0.12, N'Chưa dùng', 'KH12'),
	('PG10', 0.08, N'Chưa dùng', 'KH13'),
	('PG12', 0.25, N'Chưa dùng', 'KH02');
GO

-- 6. BẢNG SOTIENTIEU (Phụ thuộc: KH_THANHVIEN)
INSERT INTO SOTIENTIEU
	(MAKH, NAM, SOTIENDATIEU)
VALUES
	('KH01', 2024, 12000000),
	-- Bạc (>=10M, <30M)
	('KH02', 2024, 60000000),
	-- Bạch kim (>=50M)
	('KH04', 2024, 8000000),
	-- Đồng (<10M)
	('KH05', 2024, 2000000),
	-- Đồng
	('KH06', 2024, 35000000),
	-- Vàng (>=30M, <50M)
	('KH08', 2024, 15000000),
	-- Bạc
	('KH09', 2024, 500000),
	-- Đồng
	('KH10', 2024, 32000000),
	-- Vàng
	('KH12', 2024, 90000000),
	-- Bạch kim
	('KH13', 2024, 4000000);   -- Đồng
GO

-- 7. BẢNG KHUYENMAI (Phụ thuộc: NHANVIEN)
-- Lưu ý: Tạo khuyến mãi bao trùm thời điểm hiện tại để test Trigger tính tiền
INSERT INTO KHUYENMAI
	(MAKM, NGAYBATDAU, NGAYKETTHUC, MANV, ISMEMBER)
VALUES
	('KM01', '2024-01-01', '2024-02-28', 'NV01', 0),
	('KM02', '2024-03-01', '2024-12-31', 'NV01', 1),
	('KM03', '2024-06-01', '2024-12-31', 'NV01', 0),
	('KM04', '2024-11-01', '2025-03-31', 'NV02', 1),
	('KM05', '2024-12-01', '2025-06-30', 'NV03', 0),
	('KM06', '2025-01-15', '2025-04-15', 'NV03', 1),
	('KM07', '2024-11-15', '2025-01-15', 'NV01', 0),
	('KM08', '2024-10-01', '2025-01-31', 'NV02', 1),
	('KM09', '2024-12-20', '2025-02-28', 'NV04', 0),
	('KM10', '2025-02-01', '2025-05-31', 'NV05', 1),
	('KM11', '2024-05-01', '2024-12-31', 'NV01', 0),
	('KM12', '2024-09-01', '2025-03-31', 'NV02', 1),
	('KM13', '2024-11-20', '2025-02-20', 'NV03', 0),
	('KM14', '2024-12-25', '2025-01-10', 'NV04', 1),
	('KM15', '2025-01-01', '2025-12-31', 'NV05', 0),
	('KM16', '2024-07-01', '2024-12-31', 'NV06', 1),
	('KM17', '2025-03-01', '2025-08-31', 'NV07', 0),
	('KM18', '2024-11-01', '2025-06-30', 'NV08', 1),
	('KM19', '2024-12-15', '2025-01-31', 'NV09', 0),
	('KM20', '2025-01-10', '2025-04-10', 'NV10', 1),
	('KM21', '2024-08-01', '2025-01-15', 'NV01', 0),
	('KM22', '2024-11-10', '2025-03-10', 'NV02', 1),
	('KM23', '2024-12-05', '2025-02-28', 'NV03', 0),
	('KM24', '2024-12-01', '2025-01-31', 'NV04', 1),
	('KM25', '2025-02-14', '2025-03-14', 'NV05', 0),
	('KM26', '2024-10-15', '2025-04-15', 'NV06', 1),
	('KM27', '2024-11-25', '2025-05-25', 'NV07', 0),
	('KM28', '2024-12-20', '2025-06-20', 'NV08', 1),
	('KM29', '2025-03-15', '2025-09-15', 'NV09', 0),
	('KM30', '2025-04-01', '2025-12-31', 'NV10', 1);
GO

-- 8. BẢNG MEMBER_SALE (Phụ thuộc: KHUYENMAI, CAPDOTHE)
INSERT INTO MEMBER_SALE
	(MAKM, MACAPDO)
VALUES
	('KM02', 'LV2'),
	('KM02', 'LV3'),
	('KM04', 'LV3'),
	('KM04', 'LV4'),
	('KM08', 'LV4'),
	('KM12', 'LV2'),
	('KM12', 'LV3'),
	('KM14', 'LV3'),
	('KM16', 'LV2'),
	('KM18', 'LV4'),
	('KM20', 'LV1'),
	('KM22', 'LV3'),
	('KM24', 'LV2'),
	('KM26', 'LV4'),
	('KM28', 'LV3'),
	('KM30', 'LV4');
GO

-- 9. BẢNG DANHMUC (Phụ thuộc: NHANVIEN)
INSERT INTO DANHMUC
	(MADM, CHUNGLOAI, MANV)
VALUES
	('DM01', N'Thực phẩm', 'NV01'),
	('DM02', N'Đồ gia dụng', 'NV01'),
	('DM03', N'Đồ điện tử', 'NV01'),
	('DM04', N'Đồ chơi trẻ em', 'NV01'),
	('DM05', N'Mỹ phẩm', 'NV01'),
	('DM06', N'Đồ gia dụng nhỏ', 'NV10'),
	('DM07', N'Thực phẩm đóng gói', 'NV06'),
	('DM08', N'Sữa & Đồ uống', 'NV06'),
	('DM09', N'Sản phẩm chăm sóc cá nhân', 'NV07'),
	('DM10', N'Văn phòng phẩm', 'NV08');
GO

-- 10. BẢNG NHASANXUAT (Độc lập)
INSERT INTO NHASANXUAT
	(MANSX, TENNSX, DIACHI, EMAIL, SDT)
VALUES
	('NSX01', N'Vinamilk', N'Q7, TP.HCM', 'contact@vinamilk.com', '0285415555'),
	('NSX02', N'Sunhouse', N'Hà Nội', 'contact@sunhouse.com', '18006680'),
	('NSX03', N'ABC Foods', N'Q1 TP.HCM', 'contact@abcfoods.com', '0281234003'),
	('NSX04', N'Happy Home', N'Hà Nội', 'sales@happyhome.vn', '0241234004'),
	('NSX05', N'FreshFarm', N'Đà Nẵng', 'info@freshfarm.vn', '0236123405'),
	('NSX06', N'CookWell', N'Hải Phòng', 'hello@cookwell.vn', '0225123406'),
	('NSX07', N'KitchenPro', N'Hà Nội', 'support@kitchenpro.vn', '0246234007'),
	('NSX08', N'GreenLife', N'TP.HCM', 'contact@greenlife.vn', '0286344008'),
	('NSX09', N'MiniGoods', N'Vinh', 'info@minigoods.vn', '0238123409'),
	('NSX10', N'SUNNY Tech', N'Bắc Ninh', 'hello@sunnytech.vn', '0228123410');
GO

-- 11. BẢNG SANPHAM (Đã trừ Tồn kho dựa trên lượng bán trong CHITIETHOADON bên dưới)
-- Ví dụ: SP01 ban đầu 100, bán 5 -> Còn 95
INSERT INTO SANPHAM (MASP, TENSANPHAM, DONGIA, MOTASP, TONKHO, SOLUONGTOIDA, MADM, MANSX) VALUES
('SP01', N'Sữa tươi Vinamilk', 30000, N'Hộp 1 lít', 95, 500, 'DM01', 'NSX01'),
('SP02', N'Chảo chống dính', 200000, N'Size 24cm', 49, 200, 'DM02', 'NSX02'),
('SP03', N'Bánh mì gói', 15000, N'Bánh mì sandwich', 190, 500, 'DM07', 'NSX03'),
('SP04', N'Nước ngọt 330ml', 8000, N'Nước giải khát', 295, 1000, 'DM08', 'NSX03'),
('SP05', N'Bột giặt 1kg', 90000, N'Bột giặt tiện dụng', 148, 500, 'DM05', 'NSX05'),
('SP06', N'Tinh dầu gội 500ml', 120000, N'Tinh dầu cho tóc', 119, 400, 'DM09', 'NSX05'),
('SP07', N'Bình đun siêu tốc', 350000, N'Bình 1.7L', 57, 200, 'DM06', 'NSX04'),
('SP08', N'Đèn bàn LED', 220000, N'Đèn học', 76, 300, 'DM06', 'NSX07'),
('SP09', N'Găng tay bếp', 25000, N'Găng tay silicon', 94, 500, 'DM02', 'NSX04'),
('SP10', N'Dao nhà bếp', 150000, N'Dao inox', 88, 300, 'DM06', 'NSX06'),
('SP11', N'Ghế nhựa', 180000, N'Ghế tiện dụng', 38, 200, 'DM02', 'NSX09'),
('SP12', N'Túi ngủ', 400000, N'Dã ngoại', 29, 100, 'DM02', 'NSX09'),
('SP13', N'Bộ chén bát', 260000, N'Gốm sứ', 49, 200, 'DM06', 'NSX07'),
('SP14', N'Khăn mặt', 45000, N'Cotton', 198, 500, 'DM09', 'NSX08'),
('SP15', N'Sữa tắm 250ml', 75000, N'Sữa tắm hương trái cây', 149, 400, 'DM09', 'NSX05'),
('SP16', N'Tẩy rửa bếp', 60000, N'Chai 500ml', 138, 400, 'DM05', 'NSX03'),
('SP17', N'Bộ nồi inox', 1200000, N'3 món', 19, 50, 'DM06', 'NSX07'),
('SP18', N'Túi giấy', 5000, N'Túi mua hàng', 498, 2000, 'DM10', 'NSX09'),
('SP19', N'Bút bi', 5000, N'Ngòi 0.7', 1000, 5000, 'DM10', 'NSX09'), -- Không bán
('SP20', N'Giấy A4 500t', 120000, N'Giấy in', 80, 500, 'DM10', 'NSX09'), -- Không bán
('SP21', N'Bóng đèn 9W', 30000, N'LED tiết kiệm', 250, 1000, 'DM06', 'NSX08'), -- Không bán
('SP22', N'Cốc thủy tinh', 45000, N'Cốc uống', 200, 500, 'DM06', 'NSX07'), -- Không bán
('SP23', N'Ổ cắm điện', 80000, N'3 lỗ', 120, 400, 'DM06', 'NSX04'), -- Không bán
('SP24', N'Bàn học', 950000, N'Bàn gỗ nhỏ', 25, 100, 'DM02', 'NSX10'), -- Không bán
('SP25', N'Đèn ngủ', 180000, N'Đèn nhỏ', 70, 200, 'DM06', 'NSX08'), -- Không bán
('SP26', N'Khẩu trang', 15000, N'10 cái', 1000, 5000, 'DM09', 'NSX03'), -- Không bán
('SP27', N'Son môi', 200000, N'High color', 80, 300, 'DM05', 'NSX05'), -- Không bán
('SP28', N'Bình nước sport', 120000, N'1L', 90, 300, 'DM06', 'NSX08'), -- Không bán
('SP29', N'Giày thể thao', 650000, N'Size đa dạng', 40, 200, 'DM02', 'NSX10'), -- Không bán
('SP30', N'Áo phông cotton', 220000, N'Size S-XXL', 120, 500, 'DM02', 'NSX10'), -- Không bán
('SP31', N'Bộ dao nhà bếp 5 món', 450000, N'Inox cao cấp', 30, 150, 'DM06', 'NSX06'), -- Không bán
('SP32', N'Tủ lạnh mini', 3500000, N'50L', 10, 20, 'DM06', 'NSX07'), -- Không bán
('SP33', N'Quạt treo tường', 600000, N'3 tốc độ', 25, 100, 'DM06', 'NSX08'), -- Không bán
('SP34', N'Máy xay sinh tố', 800000, N'400W', 18, 80, 'DM06', 'NSX07'), -- Không bán
('SP35', N'Bình giữ nhiệt', 250000, N'500ml', 147, 500, 'DM08', 'NSX08'),
('SP36', N'Ghế văn phòng', 1500000, N'Có cần ngả', 12, 50, 'DM02', 'NSX10'), -- Không bán
('SP37', N'Máy sấy tóc', 450000, N'1200W', 22, 100, 'DM06', 'NSX07'), -- Không bán
('SP38', N'Bình sữa trẻ em', 220000, N'PPSU', 60, 200, 'DM07', 'NSX03'), -- Không bán
('SP39', N'Đồ chơi xếp hình', 180000, N'Nhựa an toàn', 70, 300, 'DM04', 'NSX09'), -- Không bán
('SP40', N'Bột ăn dặm', 140000, N'Hạt dinh dưỡng', 80, 300, 'DM07', 'NSX03'), -- Không bán
('SP41', N'Ghế ăn cho bé', 550000, N'Ghế gấp', 25, 100, 'DM04', 'NSX09'), -- Không bán
('SP42', N'Tã quần', 250000, N'Size M 50pcs', 120, 500, 'DM07', 'NSX03'), -- Không bán
('SP43', N'Đệm', 1200000, N'Đệm hơi', 15, 50, 'DM02', 'NSX10'), -- Không bán
('SP44', N'Bộ đồ ăn trẻ em', 190000, N'Siêu nhẹ', 60, 200, 'DM04', 'NSX09'), -- Không bán
('SP45', N'Cọ rửa chén', 35000, N'2 cái', 300, 1000, 'DM05', 'NSX05'), -- Không bán
('SP46', N'Chảo rán 28cm', 320000, N'Chống dính cao cấp', 70, 300, 'DM06', 'NSX04'), -- Không bán
('SP47', N'Dầu ăn 1L', 65000, N'Dầu hướng dương', 200, 1000, 'DM07', 'NSX03'), -- Không bán
('SP48', N'Đai lưng hỗ trợ', 180000, N'Thể thao', 90, 300, 'DM09', 'NSX06'), -- Không bán
('SP49', N'Bộ ốc vít', 90000, N'Bộ đa năng', 130, 500, 'DM10', 'NSX10'), -- Không bán
('SP50', N'Đồng hồ treo tường', 220000, N'Đường kính 30cm', 58, 200, 'DM06', 'NSX07');
GO

-- 12. BẢNG CHITIETKM (Giữ nguyên như cũ vì không cần tính toán lại)
INSERT INTO CHITIETKM (MASP, MAKM, SOLUONG, TILEGIAM) VALUES
('SP01', 'KM02', 10, 0.1), ('SP02', 'KM02', 500, 0.2), ('SP03', 'KM03', 500, 0.05), ('SP04', 'KM03', 400, 0.07),
('SP05', 'KM04', 200, 0.10), ('SP06', 'KM04', 150, 0.15), ('SP07', 'KM05', 50, 0.08), ('SP08', 'KM05', 100, 0.10),
('SP09', 'KM06', 200, 0.12), ('SP10', 'KM06', 80, 0.10), ('SP11', 'KM07', 100, 0.05), ('SP12', 'KM08', 40, 0.20),
('SP13', 'KM09', 60, 0.10), ('SP14', 'KM10', 300, 0.05), ('SP15', 'KM11', 150, 0.08), ('SP16', 'KM12', 200, 0.07),
('SP17', 'KM13', 20, 0.12), ('SP18', 'KM14', 1000, 0.03), ('SP19', 'KM15', 800, 0.02), ('SP20', 'KM16', 60, 0.10),
('SP21', 'KM17', 250, 0.06), ('SP22', 'KM18', 120, 0.09), ('SP23', 'KM19', 100, 0.08), ('SP24', 'KM20', 30, 0.15),
('SP25', 'KM21', 70, 0.05), ('SP26', 'KM22', 1500, 0.04), ('SP27', 'KM23', 80, 0.20), ('SP28', 'KM24', 90, 0.12),
('SP29', 'KM25', 50, 0.18), ('SP30', 'KM26', 120, 0.10), ('SP31', 'KM27', 30, 0.11), ('SP32', 'KM28', 10, 0.25),
('SP33', 'KM29', 25, 0.07), ('SP34', 'KM30', 18, 0.09), ('SP35', 'KM02', 200, 0.05), ('SP36', 'KM02', 50, 0.07),
('SP37', 'KM08', 40, 0.10), ('SP38', 'KM12', 70, 0.06), ('SP39', 'KM16', 60, 0.05), ('SP40', 'KM18', 80, 0.08),
('SP41', 'KM21', 20, 0.10), ('SP42', 'KM22', 200, 0.04), ('SP43', 'KM24', 10, 0.12), ('SP44', 'KM26', 15, 0.09),
('SP45', 'KM27', 300, 0.03), ('SP46', 'KM28', 50, 0.08), ('SP47', 'KM29', 400, 0.02), ('SP48', 'KM30', 80, 0.07),
('SP49', 'KM05', 100, 0.06), ('SP50', 'KM03', 60, 0.05);
GO

-- 16. BẢNG HOADON (Đã tính sẵn TONGTIEN sau khi trừ cả KM sản phẩm và Voucher)
INSERT INTO HOADON (MAHD, NGAYLAP, TONGTIEN, MANV, MAPG, MAKH) VALUES
('HD01', GETDATE(), 1047500, 'NV03', NULL, 'KH01'),  -- Tổng hàng: 1,047,500
('HD02', '2024-02-15', 544000, 'NV03', 'PG02', 'KH02'), -- Tổng hàng: 680,000 - Voucher 20%
('HD03', '2024-07-06', 567815, 'NV03', 'PG03', 'KH04'), -- Tổng hàng: 597,700 - Voucher 5%
('HD04', '2024-07-12', 396000, 'NV03', NULL, 'KH05'),   -- Tổng hàng: 396,000
('HD05', '2024-08-03', 159375, 'NV03', 'PG05', 'KH06'), -- Tổng hàng: 187,500 - Voucher 15%
('HD06', '2024-08-15', 1119000, 'NV03', NULL, 'KH08'),  -- Tổng hàng: 1,119,000
('HD07', '2024-09-05', 903600, 'NV03', NULL, 'KH09'),   -- Tổng hàng: 903,600
('HD08', '2024-09-15', 142500, 'NV03', 'PG07', 'KH10'), -- Tổng hàng: 150,000 - Voucher 5%
('HD09', '2024-10-05', 270000, 'NV03', NULL, 'KH12'),   -- Tổng hàng: 270,000
('HD10', '2024-10-20', 1209700, 'NV03', NULL, 'KH13');  -- Tổng hàng: 1,209,700
GO

-- 17. BẢNG CHITIETHOADON (Đã tính sẵn THANHTIEN = SL * Dongia * (1 - Tỉ lệ KM))
INSERT INTO CHITIETHOADON (MAHD, MASP, SOLUONG, THANHTIEN, MAKM) VALUES
-- HD01
('HD01', 'SP01', 5, 135000, 'KM02'),    -- 5 * 30k * 0.9
('HD01', 'SP02', 1, 200000, NULL),      -- 1 * 200k
('HD01', 'SP35', 3, 712500, 'KM02'),    -- 3 * 250k * 0.95 (KM02 cho SP35 giảm 5%)
-- HD02
('HD02', 'SP11', 2, 360000, NULL),      -- 2 * 180k
('HD02', 'SP12', 1, 320000, 'KM08'),    -- 1 * 400k * 0.8
-- HD03
('HD03', 'SP03', 10, 142500, 'KM03'),   -- 10 * 15k * 0.95
('HD03', 'SP04', 5, 37200, 'KM03'),     -- 5 * 8k * 0.93
('HD03', 'SP50', 2, 418000, 'KM03'),    -- 2 * 220k * 0.95
-- HD04
('HD04', 'SP05', 2, 162000, 'KM04'),    -- 2 * 90k * 0.9
('HD04', 'SP13', 1, 234000, 'KM09'),    -- 1 * 260k * 0.9
-- HD05
('HD05', 'SP06', 1, 102000, 'KM04'),    -- 1 * 120k * 0.85
('HD05', 'SP14', 2, 85500, 'KM10'),     -- 2 * 45k * 0.95
-- HD06
('HD06', 'SP07', 3, 1050000, NULL),     -- 3 * 350k
('HD06', 'SP15', 1, 69000, 'KM11'),     -- 1 * 75k * 0.92
-- HD07
('HD07', 'SP08', 4, 792000, 'KM05'),    -- 4 * 220k * 0.9
('HD07', 'SP16', 2, 111600, 'KM12'),    -- 2 * 60k * 0.93
-- HD08
('HD08', 'SP09', 6, 150000, NULL),      -- 6 * 25k
-- HD09
('HD09', 'SP10', 2, 270000, 'KM06'),    -- 2 * 150k * 0.9
-- HD10
('HD10', 'SP17', 1, 1200000, NULL),     -- 1 * 1.2M
('HD10', 'SP18', 2, 9700, 'KM14');      -- 2 * 5k * 0.97
GO

SELECT * FROM HOADON