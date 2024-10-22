
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

table = ["Transactions per Day,Years until Overflow".split(",")]
for trans in (100, 500, 1_000, 5_000, 10_000, 100_000, 500_000, 1_000_000):
	years = m // (365 * trans)
	table.append([trans,years])

print(tabulate(
	table,
	headers="firstrow",
	tablefmt="rounded_outline",
	intfmt=",",
))