# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    Collar(table, holeid=:HOLEID, x=:X, y=:Y, z=:Z)

Collar table and its main column fields.
"""
Base.@kwdef struct Collar
  table
  holeid::Symbol = :HOLEID
  x::Symbol      = :X
  y::Symbol      = :Y
  z::Symbol      = :Z
end

"""
    Survey(table, holeid=:HOLEID, at=:AT, azm=:AZM, dip=:DIP)

Survey table and its main columns fields.
"""
Base.@kwdef struct Survey
  table
  holeid::Symbol     = :HOLEID
  at::Symbol         = :AT
  azm::Symbol        = :AZM
  dip::Symbol        = :DIP
end

"""
    Interval(table, holeid=:HOLEID, from=:FROM, to=:TO)

Interval table and its main column fields.
"""
Base.@kwdef struct Interval
  table
  holeid::Symbol = :HOLEID
  from::Symbol   = :FROM
  to::Symbol     = :TO
end

"""
    DrillHole(table, trace, pars)

Drill hole object. `table` stores the desurveyed data. `trace` and `pars` store
parameters for eventual post-processing or later drill hole compositing.
"""
struct DrillHole
  table
  trace
  pars
end
