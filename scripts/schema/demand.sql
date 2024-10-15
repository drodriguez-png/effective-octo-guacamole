-- <0: init>
insert into TransAct(TransType,District,OrderNo,ItemName,Qty,Material,Thickness,ItemData1,ItemData2)
values
    ('SN81',1,'1230039B-1-G','1230039B_X5K',3,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X10B',1,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X11F',1,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X13C',2,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X13F',1,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X15F',9,'MS',0.750,'1230039B',1)

-- <1: revise_qty>
update Part set QtyOrdered = Part.QtyCompleted+PartWithQtyInProcess.QtyInProcess
from Part
inner join PartWithQtyInProcess
	on Part.PartName=PartWithQtyInProcess.PartName
	and Part.WONumber=PartWithQtyInProcess.WONumber
where Part.PartName = '1230039B_X11F'
insert into TransAct(TransType,District,OrderNo,ItemName)
select distinct
	'SN82' as TransType,
	1 as District,
	WONumber,
	PartName
from Part where QtyOrdered=0
insert into TransAct(TransType,District,OrderNo,ItemName,Qty,Material,Thickness,ItemData1,ItemData2)
values
    ('SN81',1,'1230039B-1-G','1230039B_X11F',30,'MS',0.750,'1230039B',1)

-- <2: add_remake>
update Part set QtyOrdered = Part.QtyCompleted+PartWithQtyInProcess.QtyInProcess
from Part
inner join PartWithQtyInProcess
	on Part.PartName=PartWithQtyInProcess.PartName
	and Part.WONumber=PartWithQtyInProcess.WONumber
where Part.PartName = '1230039B_X11F'
insert into TransAct(TransType,District,OrderNo,ItemName)
select distinct
	'SN82' as TransType,
	1 as District,
	WONumber,
	PartName
from Part where QtyOrdered=0
insert into TransAct(TransType,District,OrderNo,ItemName,Qty,Material,Thickness,ItemData1,ItemData2)
values
    ('SN81',1,'1230039B-1-G','1230039B_X11F',32,'MS',0.750,'1230039B',1)

-- <3: remove_part>
update Part set QtyOrdered = Part.QtyCompleted+PartWithQtyInProcess.QtyInProcess
from Part
inner join PartWithQtyInProcess
	on Part.PartName=PartWithQtyInProcess.PartName
	and Part.WONumber=PartWithQtyInProcess.WONumber
where Part.PartName = '1230039B_X11F'
insert into TransAct(TransType,District,OrderNo,ItemName)
select distinct
	'SN82' as TransType,
	1 as District,
	WONumber,
	PartName
from Part where QtyOrdered=0
insert into TransAct(TransType,District,OrderNo,ItemName,Qty,Material,Thickness,ItemData1,ItemData2)
values
    ('SN81',1,'1230039B-1-G','1230039B_X11F',16,'MS',0.750,'1230039B',1)

-- <4: overlay>
update Part set QtyOrdered = Part.QtyCompleted+PartWithQtyInProcess.QtyInProcess
from Part
inner join PartWithQtyInProcess
	on Part.PartName=PartWithQtyInProcess.PartName
	and Part.WONumber=PartWithQtyInProcess.WONumber
insert into TransAct(TransType,District,OrderNo,ItemName)
select distinct
	'SN82' as TransType,
	1 as District,
	WONumber,
	PartName
from Part where QtyOrdered=0
insert into Transact(TransType,District) values ('SN89I',1)
insert into TransAct(TransType,District,OrderNo,ItemName,Qty,Material,Thickness,ItemData1,ItemData2)
values
    ('SN81',1,'1230039B-1-G','1230039B_X5K',3,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X11F',16,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X13C',2,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X13F',1,'MS',0.750,'1230039B',1),
    ('SN81',1,'1230039B-1-G','1230039B_X15F',9,'MS',0.750,'1230039B',1)

-- <5: add_archived>
insert into TransAct(TransType,District,OrderNo,ItemName,Qty,Material,Thickness,ItemData1,ItemData2)
values
    ('SN81B',1,'1230039B-1-G','1230039B_X5K',10,'MS',0.750,'1230039B',1)

-- <mark>
update Part set Data17='If a re-import happens, this will be gone'

--end