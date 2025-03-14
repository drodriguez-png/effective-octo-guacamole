use SNInterDev;

-- create parts from standard shapes
DECLARE @simtrans_district INT = ( SELECT TOP 1 SimTransDistrict FROM sap.InterfaceConfig );
insert into SNDBaseDev.dbo.TransAct (
	TransType, District, OrderNo, ItemName, Qty, Material, Thickness, OrderShape, Param1, Param2, Param3, Param4
) values
	('SN83', @simtrans_district, 'part_create', '1230456A_X1A', 1, 'A709-50', 1.0, 'SHAPE51', 20, 10, 3, 0.9375),
	('SN83', @simtrans_district, 'part_create', '1230456A_X1D', 1, 'A709-50', 0.5, 'SHAPE51', 24, 10, 3, 0.9375),
	('SN83', @simtrans_district, 'part_create', '1230456A_X1C', 1, 'A709-50', 1.0, 'SHAPE51', 18, 9, 3, 0.9375),
	('SN83', @simtrans_district, 'part_create', '1230456A_X1D', 1, 'A709-50', 1.0, 'SHAPE51', 24, 8, 3, 0.9375),
	('SN83', @simtrans_district, 'part_create', '1230456A_M1A', 1, 'A709-50', 0.5, 'SHAPE51', 10, 10, 3, 0.9375);
insert into SNDBaseDev.dbo.TransAct (TransType, District, OrderNo)
values ('SN89', @simtrans_district, 'part_create');

-- clear previous test results
--delete from SNDBaseDev.dbo.TransAct where TransID like '[1-4]-%';

-- test demand create
exec sap.PushSapDemand '1-create', '123456X1A', '1230456A-1', '1230456A_X1A', 3, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-create', '123456X1B', '1230456A-1', '1230456A_X1B', 18, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-create', '123456X1C', '1230456A-1', '1230456A_X1C', 20, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-create', '123456X1D', '1230456A-1', '1230456A_X1D', 6, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-create', '123456M1A', '1230456A-1', '1230456A_M1A', 40, 'A709-50', @job='1230456A';

-- test demand change
exec sap.PushSapDemand '1-change', '123456X1A', '1230456A-1', '1230456A_X1A', 2, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-change', '123456X1B', '1230456A-1', '1230456A_X1B', 6, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-change', '123456X1B', '1230456A-2', '1230456A_X1B', 18, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-delete', '123456X1B', '1230456A-1', '1230456A_X1C', 0, 'A709-50';

-- test inventory create
exec sap.PushSapInventory '2-create', 'N1', 'New', 1, 'A709-50', 1.0, 96.0, 240.0, '50/50W-0100';
