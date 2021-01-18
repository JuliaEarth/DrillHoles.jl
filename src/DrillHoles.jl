module DrillHoles

using CSV
using DataFrames
using StatsBase:mean,weights

include("definitions.jl")
include("compositing.jl")
include("desurvey.jl")
include("mergetables.jl")
include("validations.jl")

export
    composite,
    drillhole,
    exportwarns,
    Collar,
    Interval,
    Survey
end
