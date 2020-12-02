module DrillHoles

using CSV
using DataFrames
using StatsBase:mean,weights

include("desurvey.jl")
include("mergetables.jl")
include("compositing.jl")]

export
    Collar,
    Survey,
    IntervalTable,
    drillhole,
    composite

end
