# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    Collar(file, holeid=:HOLEID, x=:X, y=:Y, z=:Z)

The definition of the drill hole collar table and its main column fields.
"""
Base.@kwdef struct Collar
  file
  holeid::Symbol = :HOLEID
  x::Symbol      = :X
  y::Symbol      = :Y
  z::Symbol      = :Z
end

"""
    Survey(file, holeid=:HOLEID, at=:AT, azm=:AZM, dip=:DIP, convention=:auto, method=:mincurv)

The definition of the drill hole survey table and its main column fields.
Dip `convention` can be `:auto`, `:positivedownwards` or `:negativedownwards`.
The default is set to `:auto` and assumes that the most common dip sign points
downwards. Available methods for desurvey are `:mincurv` (minimum curvature/
spherical arc) and `:tangential`.
"""
Base.@kwdef struct Survey
  file
  holeid::Symbol     = :HOLEID
  at::Symbol         = :AT
  azm::Symbol        = :AZM
  dip::Symbol        = :DIP
  convention::Symbol = :auto
  method::Symbol     = :mincurv
end

"""
    Interval(file, holeid=:HOLEID, from=:FROM, to=:TO)

The definition of one drill hole interval table and its main column fields.
Examples of interval tables are lithological and assay tables.
"""
Base.@kwdef struct Interval
  file
  holeid::Symbol = :HOLEID
  from::Symbol   = :FROM
  to::Symbol     = :TO
end

"""
    DrillHole(table, trace, pars, warns)

Drill hole object. `table` stores the desurveyed data. `trace` and `pars` store
parameters for eventual post-processing or later drill hole compositing. `warns`
report possible problems with input files.
"""
struct DrillHole
  table
  trace
  pars
  warns
end
