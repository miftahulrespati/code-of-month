USE [VTS_MMKSI]
GO
/****** Object:  StoredProcedure [dbo].[SP_InsertUpdate_PricingMasterData]    Script Date: 20/04/2022 21:00:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Miftah Refactory
-- Create date: 23-03-2022
-- Description:	SP Insert Update Pricing Master Data
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SP_InsertUpdate_PricingMasterData]
	@Region as varchar(500) = null, 
	@DestinationCode as nvarchar(100) = null,
	@VendorCode as int = null, 
	@ModelName as nvarchar(100) = null, 
	@Price as float = null,
	@DeliveryMode as nvarchar(100) = null, 
	@UpdatedBy as varchar(100)
AS
BEGIN

	-- while the payload sent is generally not the ID of the table, e.g. DestinationCode, Model Name
	-- the relation of each table is presented by ID, so each ID of each table needed to be initialized
	DECLARE @DestinationID bigint, @VendorID bigint, @FleetID int, @TransportModeID int, @CheckID int
	SET @DestinationID = (SELECT top 1 ID FROM MasterData_Destination with (nolock) WHERE DestinationCode = @DestinationCode and rowstatus=0)
	SET @VendorID = (SELECT top 1 ID FROM MasterData_Vendor with (nolock) WHERE VendorCode = @VendorCode and rowstatus=0)
	SET @FleetID = (SELECT top 1 ID FROM MasterData_Model with (nolock) WHERE UPPER(ModelName) = UPPER(@ModelName) and rowstatus=0)
	SET @TransportModeID = (SELECT top 1 ID FROM MasterData_DeliveryMode with (nolock) WHERE UPPER(DeliveryModeName) = UPPER(@DeliveryMode) and rowstatus=0)

	SET NOCOUNT ON;
	
    -- if any ID of the table is NULL, showing that the value does not exists
    -- a new query will be declared to be executed, then returning a message to the C# API
    -- that this particular type of this particular value was failed to be inserted
	IF @DestinationID IS NULL OR @VendorID IS NULL OR @FleetID IS NULL OR @TransportModeID IS NULL
	BEGIN
		DECLARE @sql nvarchar(max), @exec nvarchar(max)
		SET @sql = 'SELECT'
			IF @DestinationID IS NULL
			BEGIN
				SET @sql = CONCAT(@sql, ' DestinationCode = '''+ @DestinationCode +''',')
			END
	
			IF @VendorID IS NULL
			BEGIN
				SET @sql = CONCAT(@sql, ' VendorCode = '''+ CAST(@VendorCode as nvarchar) +''',')
			END
	
			IF @FleetID IS NULL
			BEGIN
				SET @sql = CONCAT(@sql, ' ModelName = '''+ @ModelName +''',')
			END	

			IF @TransportModeID IS NULL
			BEGIN
				SET @sql = CONCAT(@sql, ' DeliveryMode = '''+ @DeliveryMode +''',')
			END
			SET @exec = SUBSTRING(@sql,1,LEN(@sql)-1)
			EXEC sp_executesql @exec
    
		-- the sql return some value
		RETURN
	END
		
    -- when all the table ID is present, meaning it's ready to be inserted or updated
    -- another condition need to be check wether the data is new insertion or updating the existing one
	IF NOT EXISTS (SELECT TOP 1 * FROM MasterData_Pricing with (nolock) 
		WHERE Region = @Region AND VendorID = @VendorID 
		AND DestinationID = @DestinationID AND FleetID = @FleetID 
		AND TransportModeID = @TransportModeID AND RowStatus = 0)
    
		-- the data being inserted here
		BEGIN
			INSERT INTO [dbo].[MasterData_Pricing]
				([Region]
				,[DestinationID]
				,[VendorID]
				,[FleetID]
				,[Price]
				,[TransportModeID]
				,[RowStatus]
				,[CreatedBy]
				,[CreatedTime]
				,[LastUpdatedBy]
				,[LastUpdatedTime])
			VALUES
				(@Region
				,@DestinationID
				,@VendorID
				,@FleetID
				,@Price
				,@TransportModeID
				,0
				,@UpdatedBy
				,GETDATE()
				,NULL
				,GETDATE())
		END
		ELSE
    
		-- if the data with exactly same Region, Vendor, Destination, Fleet, and TransportMode already exists
		-- then it's data update, the price will be updated to be precise
		BEGIN
			SET @CheckID = (SELECT TOP 1 ID FROM MasterData_Pricing with (nolock) 
			WHERE Region = @Region AND VendorID = @VendorID 
			AND DestinationID = @DestinationID AND FleetID = @FleetID 
			AND TransportModeID = @TransportModeID AND RowStatus = 0)

			UPDATE [dbo].[MasterData_Pricing]
			SET [Price] = @Price
				,[LastUpdatedBy] = @UpdatedBy
				,[LastUpdatedTime] = GETDATE()
			WHERE ID = @CheckID
		END
    
    -- in the end of the code, nothing returned
    -- the C# API will detect nothing assuming the data insertion and update is successful
END
