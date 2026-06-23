# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

module DrillHoles

using Meshes
using Unitful
using GeoTables
using DataFrames
using DataScienceTraits
using TableTransforms
using LinearAlgebra

import Tables
import Interpolations

const LinearItp = Interpolations.linear_interpolation
const LinearBC = Interpolations.Line

# source code
include("units.jl")
include("tables.jl")
include("desurvey.jl")
include("composite.jl")

# precompile workloads
include("precompile.jl")

# deprecation warnings
function desurvey(collar, survey, intervals::AbstractVector; kwargs...)
  Base.depwarn(
    """
    `desurvey(collar, survey, [interval₁, interval₂, ...]; kwargs...)` is deprecated.

    Use `desurvey(collar, survey, interval₁, interval₂, ...; kwargs...)` instead.
    """,
    :desurvey,
    force=true
  )
  desurvey(collar, survey, intervals...; kwargs...)
end

export
  # types
  MiningTable,
  Survey,
  Collar,
  Interval,

  # functions
  desurvey

end
