# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

module DrillHoles

using DataFrames

import Interpolations
const LinearItp = Interpolations.LinearInterpolation
const LinearBC  = Interpolations.Line

import SpatialIndexing as SI

include("tables.jl")
include("desurvey.jl")

export
  # types
  MiningTable,
  Survey,
  Collar,
  Interval,

  # functions
  desurvey

end
