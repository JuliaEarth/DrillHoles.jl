# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

module DrillHoles

using Meshes
using DataFrames
using ScientificTypes
using TableTransforms
using LinearAlgebra

import Tables
import Interpolations

const LinearItp = Interpolations.linear_interpolation
const LinearBC = Interpolations.Line

include("tables.jl")
include("desurvey.jl")
include("composite.jl")

export
  # types
  MiningTable,
  Survey,
  Collar,
  Interval,

  # functions
  desurvey

end
