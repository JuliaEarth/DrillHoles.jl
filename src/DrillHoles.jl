# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

module DrillHoles

using CSV
using DataFrames
using StatsBase: mean, weights

include("definitions.jl")
include("compositing.jl")
include("desurvey.jl")
include("mergetables.jl")
include("validations.jl")

export
  composite,
  drillhole,
  Collar,
  Survey,
  Interval

end
