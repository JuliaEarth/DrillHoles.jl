module DrillHoles

using CSV
using DataFrames

include("desurvey.jl")
include("mergetables.jl")
include("compositing.jl")


export
    Collar,
    Survey,
    IntervalTable,
    drillhole,
    composite



"""
## Workflow draft

using DrillHoles
fp = "/home/rafa/Documents/programming/julialang/dh_functions/"
collar = Collar(file=string(fp,"collar.csv"),holeid="BHID",x="XCOLLAR",y="YCOLLAR",z="ZCOLLAR",enddepth="ENDDEPTH")
survey = Survey(file=string(fp,"survey.csv"),holeid="BHID",at="AT",azm="BRG",dip="DIP",invertdip=false)
litho = IntervalTable(file=string(fp,"litho.csv"),holeid="BHID",from="FROM",to="TO")
assay = IntervalTable(file=string(fp,"assay.csv"),holeid="BHID",from="FROM",to="TO")

dh = drillhole(collar,survey,[litho,assay])
dhcomp = composite(dh)

"""


end
