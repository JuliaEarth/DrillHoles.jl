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
collar = Collar(file="collar.csv",holeid="BHID",x="XCOLLAR",y="YCOLLAR",z="ZCOLLAR",enddepth="ENDDEPTH")
survey = Survey(file="survey.csv",holeid="BHID",at="AT",azm="BRG",dip="DIP",invertdip=false)
litho = IntervalTable(file="litho.csv",holeid="BHID",from="FROM",to="TO")
assay = IntervalTable(file="assay.csv",holeid="BHID",from="FROM",to="TO")

dh = drillhole(collar,survey,[litho,assay])

dhcomp = composite(dh,interval=1.0,zone="LITHO")
"""


end
