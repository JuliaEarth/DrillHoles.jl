# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

module DrillHoles

using CSV
using DataFrames
using StatsBase: mean, weights

include("tables.jl")
include("desurvey.jl")
include("compositing.jl")
include("mergetables.jl")

export
  # types
  Collar,
  Survey,
  Interval,

  # functions
  desurvey,
  composite

end
