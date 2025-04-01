use SNInterDev;

-- create parts from standard shapes
--DECLARE @simtrans_district INT = ( SELECT TOP 1 SimTransDistrict FROM sap.InterfaceConfig );
--insert into SNDBaseDev.dbo.TransAct (
--	TransType, District, OrderNo, ItemName, Qty, Material, Thickness, OrderShape, Param1, Param2, Param3, Param4
--) values
--	('SN83', @simtrans_district, 'part_create', '1230456A_X1A', 1, 'A709-50', 1.0, 'SHAPE51', 20, 10, 3, 0.9375),
--	('SN83', @simtrans_district, 'part_create', '1230456A_X1D', 1, 'A709-50', 0.5, 'SHAPE51', 24, 10, 3, 0.9375),
--	('SN83', @simtrans_district, 'part_create', '1230456A_X1C', 1, 'A709-50', 1.0, 'SHAPE51', 18, 9, 3, 0.9375),
--	('SN83', @simtrans_district, 'part_create', '1230456A_X1D', 1, 'A709-50', 1.0, 'SHAPE51', 24, 8, 3, 0.9375),
--	('SN83', @simtrans_district, 'part_create', '1230456A_M1A', 1, 'A709-50', 0.5, 'SHAPE51', 10, 10, 3, 0.9375);
--insert into SNDBaseDev.dbo.TransAct (TransType, District, OrderNo)
--values ('SN89', @simtrans_district, 'part_create');

-- clear previous test results
delete from SNDBaseDev.dbo.TransAct where TransID like '[1-4]-%';
select * from SNDBaseDev.dbo.TransAct;

-- test demand create
exec sap.PushSapDemand '1-create', '123456X1A', '1230456A-1', '1230456A_X1A',  3, 'A709-50', @job='1230456A', @shipment='01', @codegen='Drill';
exec sap.PushSapDemand '1-create', '123456X1B', '1230456A-1', '1230456A_X1B', 18, 'A709-50', @job='1230456A', @shipment='01', @codegen='Drill';
exec sap.PushSapDemand '1-create', '123456X1C', '1230456A-1', '1230456A_X1C', 20, 'A709-50', @job='1230456A', @shipment='01', @codegen='Drill';
exec sap.PushSapDemand '1-create', '123456X1D', '1230456A-1', '1230456A_X1D',  6, 'A709-50', @job='1230456A', @shipment='01', @codegen='Drill';
exec sap.PushSapDemand '1-create', '123456M1A', '1230456A-1', '1230456A_M1A', 40, 'A709-50', @job='1230456A', @shipment='01', @codegen='Drill';

-- test demand change
exec sap.PushSapDemand '1-change', '123456X1A', '1230456A-1', '1230456A_X1A', 2, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-change', '123456X1B', '1230456A-1', '1230456A_X1B', 6, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-change', '123456X1B', '1230456A-2', '1230456A_X1B', 18, 'A709-50', @job='1230456A';
exec sap.PushSapDemand '1-delete', '123456X1B', '1230456A-1', '1230456A_X1C', 0, 'A709-50';

-- test scan plate demand
exec sap.PushSapDemand '1-scan', '123456X1A', '1230456A-3', '1230456A_X1A',  3, 'A709-50', @job='1230456A', @shipment='03', @codegen='Drill', @process='DTE';
exec sap.PushRenamedDemand '1-scan', '456A-1A-J-X1A', '1230456A_X1A', '1230456A-3', 1;
exec sap.RemoveRenamedDemand '1-scan', 2, 1;

-- test inventory create
exec sap.PushSapInventory '2-create', 'N1', 'New', 5, 'A709-50', 1.0, 96.0, 240.0, '50/50W-0100';
exec sap.PushSapInventory '2-create', 'R123', 'Remnant', 1, 'A709-50', 1.0, 72.0, 240.0, '9-50-0100';

-- test inventory change
exec sap.PushSapInventory '2-change', 'N1',  'New', 4, 'A709-50', 1.0, 96.0, 240.0, '50/50W-0100';
exec sap.PushSapInventory '2-change', 'N1a', 'New', 1, 'A709-50', 1.0, 96.0, 264.0, '50/50W-0100';

-- test split plate
exec sap.PushSapInventory '2-split', 'N1', 'New', 3, 'A709-50', 1.0, 96.0, 240.0, '50/50W-0100';
exec sap.PushSapInventory '2-split', 'N1-s1', 'Future Remnant', 1, 'A709-50', 1.0, 96.0, 140.0, '50/50W-0100';
exec sap.PushSapInventory '2-split', 'N1-s2', 'Future Remnant', 1, 'A709-50', 1.0, 96.0, 100.0, '50/50W-0100';

-- test inventory change (in process)
exec sap.PushSapInventory '2-changeIp', '50/50WT2-7/8', 'New', 1, '50/50WT2', 0.875, 96, 240, '50/50WT2-7/8';
exec sap.PushSapInventory '2-changeIp', '50/50WT2-7/8', 'New', 3, '50/50WT2', 0.875, 96, 240, '50/50WT2-7/8';
exec sap.PushSapInventory '2-changeIp', '50/50WT2-7/8', 'New', 0, '50/50WT2', 0.875, 96, 240, '50/50WT2-7/8';

-- test inventory delete
exec sap.PushSapInventory '2-delete', null, '50/50W-0100', 0, 'A709-50', 1.0, 96.0, 240.0, '50/50W-0100';

-- test inventory @sheet_name validation failure
exec sap.PushSapInventory '2-fail', 'R1?23', 'Remnant', 1, 'A709-50', 1.0, 4.0, 4.0, 'should_fail';

-- test feedback export
--insert into oys.Status (ProgramGUID, StatusGUID, SigmanestStatus, Source, UserName)
--select ProgramGUID, NEWID(), 'Deleted',  'UnitTest', CURRENT_USER
--from oys.Program where AutoId=2;

-- test feedback
exec sap.GetFeedback;
--exec sap.MarkFeedbackSapUploadComplete @feedback_id=5

-- test program release
exec sap.ReleaseProgram 7, 'unit-test'

-- test program update
exec sap.UpdateProgram '4-std', 3, 'unit-test'
exec sap.UpdateProgram '4-slab', 7, 'unit-test'

-- test program delete
exec sap.DeleteProgram '4-delete', 7, 'unit-test'