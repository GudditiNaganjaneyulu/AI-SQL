/* =====================================================================
   DP-800 Study Guide — Lab database setup
   Target : Azure SQL Database, SQL database in Fabric, or SQL Server 2025
   Run in : an EMPTY database named DP800Lab (create it first)
   Safe to re-run: drops and recreates the lab objects.
   Requires compatibility level 160+ (GENERATE_SERIES); 170 recommended.
   ===================================================================== */

-- Use the newest language features (REGEXP_LIKE, AI_GENERATE_CHUNKS need 170)
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 170;
GO

/* ---------- Clean up previous runs (child tables first) ---------- */
DROP TABLE IF EXISTS Sales.OrderLines;
DROP TABLE IF EXISTS Sales.Orders;
DROP TABLE IF EXISTS Sales.Products;
DROP TABLE IF EXISTS Sales.Customers;
DROP TABLE IF EXISTS HR.Employees;
GO

IF SCHEMA_ID(N'Sales') IS NULL EXEC (N'CREATE SCHEMA Sales');
IF SCHEMA_ID(N'HR')    IS NULL EXEC (N'CREATE SCHEMA HR');
GO

/* ---------- Tables ---------- */
CREATE TABLE Sales.Customers
(
    CustomerID int           IDENTITY(1,1) NOT NULL,
    FirstName  nvarchar(50)                NOT NULL,
    LastName   nvarchar(50)                NOT NULL,
    Email      nvarchar(254)               NULL,
    Phone      varchar(20)                 NULL,
    Country    nvarchar(50)                NOT NULL,
    CreatedAt  datetime2(0)                NOT NULL CONSTRAINT DF_Customers_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerID)
);

CREATE TABLE Sales.Products
(
    ProductID    int            IDENTITY(1,1) NOT NULL,
    Sku          varchar(20)                  NOT NULL,
    Name         nvarchar(200)                NOT NULL,
    Category     nvarchar(50)                 NOT NULL,
    Price        decimal(10,2)                NOT NULL,
    Description  nvarchar(2000)               NULL,
    Tags         nvarchar(200)                NULL,
    Attributes   json                         NULL,
    Discontinued bit                          NOT NULL CONSTRAINT DF_Products_Discontinued DEFAULT (0),
    CreatedAt    datetime2(0)                 NOT NULL CONSTRAINT DF_Products_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Products       PRIMARY KEY CLUSTERED (ProductID),
    CONSTRAINT UQ_Products_Sku   UNIQUE (Sku),
    CONSTRAINT CK_Products_Price CHECK (Price >= 0)
);

CREATE TABLE Sales.Orders
(
    OrderID     int          IDENTITY(1,1) NOT NULL,
    CustomerID  int                        NOT NULL,
    OrderDate   datetime2(0)               NOT NULL,
    ShippedDate datetime2(0)               NULL,
    Status      nvarchar(20)               NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES Sales.Customers (CustomerID),
    CONSTRAINT CK_Orders_Status CHECK (Status IN (N'New', N'Paid', N'Shipped', N'Cancelled'))
);

CREATE TABLE Sales.OrderLines
(
    OrderID    int           NOT NULL,
    LineNumber smallint      NOT NULL,
    ProductID  int           NOT NULL,
    Quantity   int           NOT NULL,
    UnitPrice  decimal(10,2) NOT NULL,
    CONSTRAINT PK_OrderLines PRIMARY KEY CLUSTERED (OrderID, LineNumber),
    CONSTRAINT FK_OrderLines_Orders   FOREIGN KEY (OrderID)   REFERENCES Sales.Orders (OrderID),
    CONSTRAINT FK_OrderLines_Products FOREIGN KEY (ProductID) REFERENCES Sales.Products (ProductID),
    CONSTRAINT CK_OrderLines_Quantity CHECK (Quantity > 0)
);

CREATE TABLE HR.Employees
(
    EmployeeID int           NOT NULL,
    FullName   nvarchar(100) NOT NULL,
    Title      nvarchar(100) NOT NULL,
    ManagerID  int           NULL,
    Salary     decimal(10,2) NOT NULL,
    Bonus      decimal(10,2) NULL,
    CONSTRAINT PK_Employees PRIMARY KEY CLUSTERED (EmployeeID),
    CONSTRAINT FK_Employees_Manager FOREIGN KEY (ManagerID) REFERENCES HR.Employees (EmployeeID)
);
GO

/* ---------- Indexes on foreign keys ---------- */
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID       ON Sales.Orders (CustomerID);
CREATE NONCLUSTERED INDEX IX_OrderLines_ProductID    ON Sales.OrderLines (ProductID);
GO

/* ---------- Customers (15) ---------- */
INSERT INTO Sales.Customers (FirstName, LastName, Email, Phone, Country)
VALUES (N'Asha',   N'Rao',      N'asha.rao@example.com',     '555-201-1001', N'India'),
       (N'Ben',    N'Carter',   N'ben.carter@example.com',   '555-201-1002', N'UK'),
       (N'Chen',   N'Li',       N'chen.li@example.com',      '555-201-1003', N'Singapore'),
       (N'Diego',  N'Lopez',    N'diego.lopez@example.com',  '555-201-1004', N'Mexico'),
       (N'Emma',   N'Schmidt',  N'emma.schmidt@example.com', '555-201-1005', N'Germany'),
       (N'Farah',  N'Khan',     N'farah.khan@example.com',   '555-201-1006', N'UAE'),
       (N'George', N'Brown',    N'george.brown@example.com', '555-201-1007', N'USA'),
       (N'Hana',   N'Sato',     N'hana.sato@example.com',    '555-201-1008', N'Japan'),
       (N'Ivan',   N'Petrov',   NULL,                        '555-201-1009', N'Bulgaria'),
       (N'Julia',  N'Silva',    N'julia.silva@example.com',  NULL,           N'Brazil'),
       (N'Kofi',   N'Mensah',   N'kofi.mensah@example.com',  '555-201-1011', N'Ghana'),
       (N'Lena',   N'Novak',    N'lena.novak@example.com',   '555-201-1012', N'Czechia'),
       (N'Mohan',  N'Iyer',     N'mohan.iyer@example.com',   '555-201-1013', N'India'),
       (N'Nora',   N'Smith',    N'nora.smith@example.com',   '555-201-1014', N'USA'),
       (N'Omar',   N'Haddad',   N'omar.haddad@example.com',  '555-201-1015', N'UAE');
GO

/* ---------- Products (20) ---------- */
INSERT INTO Sales.Products (Sku, Name, Category, Price, Description, Tags, Attributes)
VALUES
('TNT-UL2',  N'Trailhead UL2 Tent',          N'Camping',  289.00, N'Ultralight two-person backpacking tent with a waterproof rainfly and quick-pitch poles. Weighs just over one kilogram.', N'tent,ultralight,waterproof', N'{"capacity":2,"weightKg":1.1,"color":"green","seasons":3}'),
('TNT-FAM6', N'Basecamp Family 6 Tent',      N'Camping',  449.00, N'Spacious six-person cabin tent for car camping with two rooms, tall walls and a large vestibule for gear.',        N'tent,family',                N'{"capacity":6,"weightKg":9.8,"color":"blue","seasons":3}'),
('TNT-4S2',  N'Summit Expedition Tent',      N'Camping',  699.00, N'Four-season mountaineering tent built to withstand high winds and heavy snow loads.',                              N'tent,winter,expedition',     N'{"capacity":2,"weightKg":3.4,"color":"orange","seasons":4}'),
('SLP-DWN0', N'Alpine Down Sleeping Bag',    N'Camping',  329.00, N'Goose-down mummy sleeping bag rated to minus ten degrees Celsius for cold winter nights.',                         N'sleeping bag,winter,down',   N'{"tempRatingC":-10,"fill":"down","weightKg":1.3}'),
('SLP-SYN5', N'Trail Synthetic Sleeping Bag',N'Camping',   99.00, N'Budget synthetic sleeping bag for summer camping; stays warm even when damp.',                                     N'sleeping bag,summer',        N'{"tempRatingC":5,"fill":"synthetic","weightKg":1.6}'),
('PAD-AIR',  N'CloudRest Air Pad',           N'Camping',  129.00, N'Insulated inflatable sleeping pad that packs down to the size of a water bottle.',                                  N'sleeping pad,ultralight',    N'{"rValue":4.2,"weightKg":0.45}'),
('STV-CAN',  N'JetFlame Canister Stove',     N'Cooking',   59.00, N'Compact canister stove that boils a liter of water in about three minutes. Uses isobutane fuel.',                  N'stove,cooking',              N'{"fuel":"isobutane","weightKg":0.09}'),
('STV-WOOD', N'Forager Wood Stove',          N'Cooking',   79.00, N'Wood-burning camp stove that uses twigs and leaves, so you never carry fuel.',                                     N'stove,cooking,wood',         N'{"fuel":"wood","weightKg":0.6}'),
('CKW-TI',   N'Titanium Cook Pot',           N'Cooking',   49.00, N'Feather-light titanium pot with folding handles; doubles as a mug.',                                               N'cookware,ultralight',        N'{"volumeL":0.9,"weightKg":0.11}'),
('FLT-SQZ',  N'PureFlow Squeeze Filter',     N'Cooking',   39.00, N'Hollow-fiber water filter that removes bacteria and protozoa from streams and lakes.',                              N'water,filter',               N'{"liters":100000,"weightKg":0.08}'),
('JKT-RAIN', N'Stormshell Rain Jacket',      N'Clothing', 179.00, N'Breathable waterproof hard-shell jacket with taped seams and an adjustable hood for wet hikes.',                   N'jacket,waterproof,rain',     N'{"waterproofMm":20000,"color":"red"}'),
('JKT-DOWN', N'Glacier Down Parka',          N'Clothing', 349.00, N'Insulated winter parka with 800-fill down; very warm for snow and freezing temperatures.',                        N'jacket,winter,down',         N'{"fill":800,"color":"black"}'),
('JKT-FLC',  N'Ridge Fleece Jacket',         N'Clothing',  89.00, N'Midweight fleece layer that keeps you warm on cool evenings around camp.',                                        N'jacket,fleece',              N'{"weightGsm":200,"color":"grey"}'),
('BOT-HIK',  N'Switchback Hiking Boots',     N'Footwear', 219.00, N'Waterproof leather hiking boots with ankle support and grippy soles for rocky trails.',                           N'boots,hiking,waterproof',    N'{"waterproof":true,"weightKg":1.2}'),
('SHO-TRL',  N'Swift Trail Runners',         N'Footwear', 139.00, N'Lightweight trail-running shoes that drain quickly after river crossings.',                                       N'shoes,trail running',        N'{"waterproof":false,"weightKg":0.6}'),
('PCK-45',   N'Ascent 45L Backpack',         N'Packs',    199.00, N'Forty-five liter backpacking pack with an adjustable frame and hip-belt pockets for multi-day trips.',             N'backpack,multi-day',         N'{"volumeL":45,"weightKg":1.4}'),
('PCK-DAY',  N'Daytripper 20L Pack',         N'Packs',     69.00, N'Small day pack with a hydration sleeve, perfect for short hikes.',                                                N'backpack,day hike',          N'{"volumeL":20,"weightKg":0.5}'),
('LMP-HEAD', N'Beacon Headlamp',             N'Lighting',  45.00, N'Rechargeable 400-lumen headlamp with a red night-vision mode.',                                                    N'light,headlamp',             N'{"lumens":400,"rechargeable":true}'),
('LMP-LANT', N'Glow Camp Lantern',           N'Lighting',  35.00, N'Collapsible LED lantern that lights up the whole tent; USB rechargeable.',                                         N'light,lantern',              N'{"lumens":250,"rechargeable":true}'),
('NAV-GPS',  N'Pathfinder GPS Watch',        N'Navigation',299.00,N'GPS watch with topographic maps, altimeter and multi-day battery life for navigation off trail.',                  N'gps,watch,navigation',       N'{"batteryDays":14,"maps":true}');
GO

UPDATE Sales.Products SET Discontinued = 1 WHERE Sku = 'SLP-SYN5';
GO

/* ---------- Orders (40) and order lines, generated deterministically ---------- */
INSERT INTO Sales.Orders (CustomerID, OrderDate, ShippedDate, Status)
SELECT ((s.value * 7) % 15) + 1                                        AS CustomerID,
       DATEADD(DAY, -s.value * 9, CAST('20261001' AS datetime2(0)))    AS OrderDate,
       CASE WHEN s.value % 5 IN (0, 1) THEN NULL
            ELSE DATEADD(DAY, -s.value * 9 + 3, CAST('20261001' AS datetime2(0))) END AS ShippedDate,
       CASE s.value % 5 WHEN 0 THEN N'New' WHEN 1 THEN N'Cancelled' WHEN 2 THEN N'Paid' ELSE N'Shipped' END AS Status
FROM GENERATE_SERIES(1, 40) AS s
ORDER BY s.value;                       -- OrderID 1..40 follow s.value
GO

INSERT INTO Sales.OrderLines (OrderID, LineNumber, ProductID, Quantity, UnitPrice)
SELECT o.OrderID,
       l.value                                          AS LineNumber,
       ((o.OrderID * 7 + l.value * 3) % 20) + 1         AS ProductID,
       ((o.OrderID + l.value) % 3) + 1                  AS Quantity,
       p.Price                                          AS UnitPrice
FROM Sales.Orders AS o
CROSS APPLY GENERATE_SERIES(1, (o.OrderID % 3) + 1) AS l
JOIN Sales.Products AS p ON p.ProductID = ((o.OrderID * 7 + l.value * 3) % 20) + 1;
GO

/* ---------- Employees (hierarchy for recursive CTE labs) ---------- */
INSERT INTO HR.Employees (EmployeeID, FullName, Title, ManagerID, Salary, Bonus)
VALUES (1,  N'Priya Menon',   N'CEO',                   NULL, 250000, 50000),
       (2,  N'Tom Becker',    N'VP Sales',              1,    180000, 30000),
       (3,  N'Aiko Tanaka',   N'VP Engineering',        1,    185000, 30000),
       (4,  N'Luis Ortega',   N'Sales Manager EMEA',    2,    120000, 15000),
       (5,  N'Grace Okafor',  N'Sales Manager APAC',    2,    118000, 15000),
       (6,  N'Sam Wilson',    N'Engineering Manager',   3,    150000, 20000),
       (7,  N'Rita Das',      N'Sales Rep',             4,     70000,  8000),
       (8,  N'Jonas Berg',    N'Sales Rep',             4,     68000,  7000),
       (9,  N'Mei Wong',      N'Sales Rep',             5,     69000,  7500),
       (10, N'Arjun Shah',    N'Database Developer',    6,    110000, 10000),
       (11, N'Elena Rossi',   N'AI Engineer',           6,    125000, 12000),
       (12, N'Noah Kim',      N'Junior Developer',      10,    75000,  NULL);
GO

/* ---------- Verify ---------- */
SELECT N'Customers' AS TableName, COUNT(*) AS NumRows FROM Sales.Customers
UNION ALL SELECT N'Products',   COUNT(*) FROM Sales.Products
UNION ALL SELECT N'Orders',     COUNT(*) FROM Sales.Orders
UNION ALL SELECT N'OrderLines', COUNT(*) FROM Sales.OrderLines
UNION ALL SELECT N'Employees',  COUNT(*) FROM HR.Employees;
-- Expected: Customers 15, Products 20, Orders 40, OrderLines 80, Employees 12
