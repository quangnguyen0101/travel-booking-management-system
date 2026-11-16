/*
 BTL2 - Nhóm 5
 Kiểm tra cấu trúc sau khi chạy 01_schema.sql.
 File này chỉ đọc thông tin, không thay đổi bảng hay dữ liệu.
*/
USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;

-- 1. Đếm số bảng đã tạo, kết quả cần bằng 36.
SELECT COUNT(*) AS TableCount
FROM sys.tables
WHERE schema_id = SCHEMA_ID(N'dbo') AND is_ms_shipped = 0;

-- 2. Xem số cột và số dòng của từng bảng. Chưa thêm dữ liệu thì RowCount bằng 0.
SELECT t.name AS TableName,
       (SELECT COUNT(*) FROM sys.columns AS c WHERE c.object_id = t.object_id) AS ColumnCount,
       (SELECT SUM(p.rows) FROM sys.partitions AS p
        WHERE p.object_id = t.object_id AND p.index_id IN (0,1)) AS [RowCount]
FROM sys.tables AS t
WHERE t.schema_id = SCHEMA_ID(N'dbo') AND t.is_ms_shipped = 0
ORDER BY t.name;

-- 3. Tìm bảng chưa có khóa chính. Nếu đủ PK thì kết quả không có dòng nào.
SELECT t.name AS TableWithoutPrimaryKey
FROM sys.tables AS t
WHERE t.schema_id = SCHEMA_ID(N'dbo') AND t.is_ms_shipped = 0
  AND NOT EXISTS (SELECT 1 FROM sys.key_constraints AS k
                  WHERE k.parent_object_id = t.object_id AND k.type = 'PK');

-- 4. Liệt kê các ràng buộc để đối chiếu và chụp kết quả báo cáo.
SELECT OBJECT_NAME(o.parent_object_id) AS TableName,
       o.name AS ConstraintName, o.type_desc AS ConstraintType
FROM sys.objects AS o
WHERE o.type IN ('PK','UQ','F','C','D')
  AND OBJECT_SCHEMA_NAME(o.parent_object_id) = N'dbo'
ORDER BY TableName, ConstraintType, ConstraintName;

-- 5. Tìm FK/CHECK bị tắt hoặc chưa được xác thực. Kết quả cần rỗng.
SELECT OBJECT_NAME(parent_object_id) AS TableName, name AS ConstraintName,
       is_disabled, is_not_trusted
FROM sys.foreign_keys
WHERE schema_id = SCHEMA_ID(N'dbo') AND (is_disabled = 1 OR is_not_trusted = 1)
UNION ALL
SELECT OBJECT_NAME(parent_object_id), name, is_disabled, is_not_trusted
FROM sys.check_constraints
WHERE schema_id = SCHEMA_ID(N'dbo') AND (is_disabled = 1 OR is_not_trusted = 1);

-- 6. Xem các cột tham gia khóa ngoại, kể cả khóa ngoại ghép.
SELECT fk.name AS ForeignKey,
       OBJECT_NAME(fk.parent_object_id) AS ChildTable,
       pc.name AS ChildColumn,
       OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
       rc.name AS ParentColumn,
       fkc.constraint_column_id AS ColumnOrder
FROM sys.foreign_keys AS fk
JOIN sys.foreign_key_columns AS fkc ON fk.object_id = fkc.constraint_object_id
JOIN sys.columns AS pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
JOIN sys.columns AS rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id
WHERE fk.schema_id = SCHEMA_ID(N'dbo')
ORDER BY ForeignKey, ColumnOrder;
