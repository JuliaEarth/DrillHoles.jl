module DrillHoles

using CSV
using DataFrames

include("desurvey.jl")
include("mergetables.jl")
include("compositing.jl")

"""
export
    f1,
    f2,
    f3
"""



"""
## Workflow draft
collar = Collar("file.csv",holeid="BHID",x="X",y="Y",z="Z",enddepth="ENDDEPTH")
survey = Survey("file.csv",holeid="BHID",at="AT",azm="BRG",dip="DIP",invertdip=false)
litho = IntervalTable("file.csv",holeid="BHID",from="FROM",to="TO")
assay = IntervalTable("file.csv",holeid="BHID",from="FROM",to="TO")

dh = DrillHole(collar,survey,[litho,assay])

dhcomp = composite(dh,interval=1.0,zone="LITHO")
"""


end
