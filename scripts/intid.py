
from tabulate import tabulate

m = 2_147_483_647

print("SQL Server INT ID Overflow")

table = ["Years,Per Day,Per Week,Per Year".split(",")]
for years in (1, 2, 5, 10, 25, 50, 100):
	table.append([
		years,
		m // (365 * years),
		m // (52 * years),
		m // years,
	])

print(tabulate(
	table,
	headers="firstrow",
	tablefmt="rounded_outline",
	intfmt=",",
))