-- init data
-- <0: init>
insert into TransAct(TransType,District,ItemName,Qty,Material,Thickness,Width,Length,PrimeCode)
values
    ('SN91A',1,'50/50W-0012',12,'MS',0.750,96.000,240.000,'50/50W-0012')

-- set 1 as batch level
-- <1: batch_level>
insert into TransAct(TransType,District)
values
    ('SN95',1),
    ('SN95R',1)
insert into TransAct(TransType,District,ItemName,Qty,Material,Thickness,Width,Length,PrimeCode)
values
    ('SN91A',1,'50/50W-0012',11,'MS',0.750,96.000,240.000,'50/50W-0012'),
    ('SN91A',1,'S001',1,'MS',0.750,96.000,288.000,'50/50W-0012')

-- change 1 to remnant
-- <2: to_remnant>
insert into TransAct(TransType,District)
values
    ('SN95',1),
    ('SN95R',1)
insert into TransAct(TransType,District,ItemName,Qty,Material,Thickness,Width,Length,PrimeCode,FileName)
values
    ('SN91A',1,'50/50W-0012',10,'MS',0.750,96.000,240.000,'50/50W-0012',null),
    ('SN91A',1,'S001',1,'MS',0.750,96.000,288.000,'50/50W-0012',null),
    ('SN97',1,'R008',1,'MS',0.750,null,null,'50/50W-0012','C:\Users\PMiller1\Documents\SNDataISap\DXF\Remnants\BR04.DXF')

-- change mm of remnant
-- <3: remnant_to_mm>
insert into TransAct(TransType,District)
values
    ('SN95',1),
    ('SN95R',1)
insert into TransAct(TransType,District,ItemName,Qty,Material,Thickness,Width,Length,PrimeCode,FileName)
values
    ('SN91A',1,'50/50W-0012',10,'MS',0.750,96.000,240.000,'50/50W-0012',null),
    ('SN91A',1,'S001',1,'MS',0.750,96.000,288.000,'50/50W-0012',null),
    ('SN97',1,'R008',1,'MS',0.750,null,null,'9-MS-0012','C:\Users\PMiller1\Documents\SNDataISap\DXF\Remnants\BR04.DXF')

-- full overlay
-- <4: overlay>
insert into TransAct(TransType,District)
values
    ('SN95',1),
    ('SN95R',1)
insert into TransAct(TransType,District,ItemName,Qty,Material,Thickness,Width,Length,PrimeCode,FileName)
values
    ('SN91A',1,'50/50W-0012',10,'MS',0.750,96.000,240.000,'50/50W-0012',null),
    ('SN91A',1,'S001',1,'MS',0.750,96.000,288.000,'50/50W-0012',null),
    ('SN97',1,'R008',1,'MS',0.750,null,null,'9-MS-0012','C:\Users\PMiller1\Documents\SNDataISap\DXF\Remnants\BR04.DXF')

-- <mark>
update Stock set SpecialInstruction='If a re-import happens, this will be gone'

--end