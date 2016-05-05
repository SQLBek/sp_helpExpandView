/*===============================================================================
-- Script - EXEC sp_helpExpandView For All Views.sql
-- 
-- Written By: Andy Yun
-- Created On: 2015-03-09
-- 
-- Summary:
-- This tool script was written to as a companion to sp_helpExpandView.  You
-- can run it against a database and it will return a horizontal output of
-- all Views & their children.  Then dump the output to Excel for easier 
-- analysis & filtering of your database's nested views.
--
-- Supports:
--      Scalar & Table-Valued Functions
--      Schemas
--      Synonyms to other DBs
--
-- 
-- Updates:
-- Date			Developer	Remarks
-- 2015-03-09	AYun		V1: Initial Release
---------------------------------------------------------------------------------
-- License: 
-- This code is free to use for personal, educational, and internal corporate 
-- purposes provided that this header is preserved. 
-- (c) 2015 Andy Yun
===============================================================================*/

IF OBJECT_ID('tempdb.dbo.#tmpExpandViewHorizontal ', 'U') IS NOT NULL
	DROP TABLE #tmpExpandViewHorizontalLoop;
IF OBJECT_ID('tempdb.dbo.#tmpExpandViewHorizontal ', 'U') IS NOT NULL
	DROP TABLE #tmpExpandViewHorizontal;

CREATE TABLE #tmpExpandViewHorizontalLoop (
	RecID INT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
	HierarchyLvl INT,
	BaseObject_FullName VARCHAR(500),
	Child_DBName VARCHAR(256),
	Child_FullName VARCHAR(500),
	Child_Type CHAR(2),
	ObjectHierarchyID INT,
	ParentObjectHierarchyID INT
)

CREATE TABLE #tmpExpandViewHorizontal (
	RecID INT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
	ObjectID INT,
	HierarchyLvl INT,
	BaseObject_FullName VARCHAR(500),
	Child_DBName VARCHAR(256),
	Child_FullName VARCHAR(500),
	Child_Type CHAR(2),
	ObjectHierarchyID INT,
	ParentObjectHierarchyID INT
)

DECLARE @sqlCMD NVARCHAR(4000),
	@ObjectID INT

-----
-- Loop through every view in the current database
DECLARE curExpandView CURSOR FAST_FORWARD FOR 
	SELECT views.object_id,
		'EXEC sp_helpExpandView @ViewName = ''' + schemas.name + '.' + views.name + ''', @OutputFormat = ''Vertical'''
	FROM sys.views
	INNER JOIN sys.schemas
		ON views.schema_id = schemas.schema_id
	-- Uncomment below to add in criteria. For example, only views that use ROW_NUMBER
	--INNER JOIN sys.sql_modules
	--	ON views.object_id = sql_modules.object_id
	--WHERE sql_modules.definition LIKE '%ROW_NUMBER%'

OPEN curExpandView

FETCH NEXT 
	FROM curExpandView INTO @ObjectID, @sqlCMD

WHILE @@FETCH_STATUS = 0
	BEGIN
	
	INSERT INTO #tmpExpandViewHorizontalLoop (
		HierarchyLvl,
		BaseObject_FullName,
		Child_DBName,
		Child_FullName,
		Child_Type,
		ObjectHierarchyID,
		ParentObjectHierarchyID
	)
	EXEC sp_executesql @sqlCMD

	INSERT INTO #tmpExpandViewHorizontal (
		ObjectID,
		HierarchyLvl,
		BaseObject_FullName,
		Child_DBName,
		Child_FullName,
		Child_Type,
		ObjectHierarchyID,
		ParentObjectHierarchyID
	)
	SELECT 
		@ObjectID,
		HierarchyLvl,
		BaseObject_FullName,
		Child_DBName,
		Child_FullName,
		Child_Type,
		ObjectHierarchyID,
		ParentObjectHierarchyID
	FROM #tmpExpandViewHorizontalLoop

	TRUNCATE TABLE #tmpExpandViewHorizontalLoop;

	FETCH NEXT 
 		FROM curExpandView INTO @ObjectID, @sqlCMD
	END  
CLOSE curExpandView
DEALLOCATE curExpandView

-----
-- Dynamically create flattened output
DECLARE @MaxHierarchyID INT,
	@HierarchyID INT = 2;

SELECT @MaxHierarchyID = MAX(HierarchyLvl)
FROM #tmpExpandViewHorizontal;

DECLARE @sqlSelect NVARCHAR(4000) = N'
SELECT 
	Lvl1.BaseObject_FullName
	, Lvl1.HierarchyLvl AS Lvl_1
	, Lvl1.Child_FullName AS Obj_1
	, Lvl1.Child_Type AS Typ_1',
	@sqlFrom NVARCHAR(4000) = N'
FROM #tmpExpandViewHorizontal Lvl1';

WHILE @HierarchyID <= @MaxHierarchyID
BEGIN
	SET @sqlSelect = @sqlSelect + N'
	, COALESCE(Lvl' + CAST(@HierarchyID AS NVARCHAR(4000)) + '.HierarchyLvl, ''' + CAST(@HierarchyID AS NVARCHAR(4000)) + ''') AS Lvl_' + CAST(@HierarchyID AS NVARCHAR(4000)) + '
	, COALESCE(Lvl' + CAST(@HierarchyID AS NVARCHAR(4000)) + '.Child_FullName, SPACE(0)) AS Obj_' + CAST(@HierarchyID AS NVARCHAR(4000)) + '
	, COALESCE(Lvl' + CAST(@HierarchyID AS NVARCHAR(4000)) + '.Child_Type, SPACE(0)) AS Typ_' + CAST(@HierarchyID AS NVARCHAR(4000));
	SET @sqlFrom = @sqlFrom + N'
LEFT OUTER JOIN #tmpExpandViewHorizontal Lvl' + CAST(@HierarchyID AS NVARCHAR(4000)) + '
	ON Lvl' + CAST((@HierarchyID - 1) AS NVARCHAR(4000)) + '.ObjectHierarchyID = Lvl' + CAST(@HierarchyID AS NVARCHAR(4000)) + '.ParentObjectHierarchyID
	AND Lvl' + CAST((@HierarchyID - 1) AS NVARCHAR(4000)) + '.ObjectID = Lvl' + CAST(@HierarchyID AS NVARCHAR(4000)) + '.ObjectID

	AND Lvl' + CAST(@HierarchyID AS NVARCHAR(4000)) + '.HierarchyLvl = ' + CAST(@HierarchyID AS NVARCHAR(4000));
	SET @HierarchyID = @HierarchyID + 1;
END

SET @sqlCMD = @sqlSelect + @sqlFrom + N'
WHERE Lvl1.HierarchyLvl = 1
ORDER BY Lvl1.BaseObject_FullName, Lvl1.HierarchyLvl, Lvl1.Child_FullName;';
PRINT @sqlCMD;
EXEC sp_executesql @sqlCMD;

-----------

SELECT *
FROM #tmpExpandViewHorizontal
WHERE #tmpExpandViewHorizontal.Child_Type = 'U'
