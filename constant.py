seasonList=[ [12,  2], [3, 5], [6,  8], [9,  11]]
monthlyList=[ [12, 1], [1, 2],[2,3],[3,4],[4,5],[5,6],[6, 7],[7, 8],[8,9], [9, 10],[10, 11],[11,12]]
wrfout_data_fmt="%Y-%m-%d_%H:%M:%S"
prefix="wrfout*"
dry_lim=1
qvalue=0.95
G = 9.81
Rd = 287.04
Rv = 461.6
Rm = .608 
Cp = 1004.
Cp = 7.*Rd/2.
Cv = Cp-Rd
CPMD = 0.887
RCP = Rd/Cp
p0 = 100000.

