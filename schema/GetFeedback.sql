select * from STPrgArc
select * from STPIPArc

select * from SIP
select * from Stock where SheetName in (select SheetName from STPIPArc)
select * from Remnant