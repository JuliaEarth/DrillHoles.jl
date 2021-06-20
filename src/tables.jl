# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    MiningTable

A table from the mining industry (e.g. survey, collar, interval).
"""
abstract type MiningTable end

"""
    Survey(table, holeid=:HOLEID, at=:AT, azm=:AZM, dip=:DIP)

Survey table and its main columns fields.
"""
struct Survey{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  at::Symbol
  azm::Symbol
  dip::Symbol
end

Survey(table; holeid=:HOLEID, at=:AT, azm=:AZM, dip=:DIP) =
  Survey(table, holeid, at, azm, dip)

"""
    Collar(table, holeid=:HOLEID, x=:X, y=:Y, z=:Z)

Collar table and its main column fields.
"""
struct Collar{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  x::Symbol
  y::Symbol
  z::Symbol
end

Collar(table; holeid=:HOLEID, x=:X, y=:Y, z=:Z) =
  Collar(table, holeid, x, y, z)

"""
    Interval(table, holeid=:HOLEID, from=:FROM, to=:TO)

Interval table and its main column fields.
"""
struct Interval{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  from::Symbol
  to::Symbol
end

Interval(table; holeid=:HOLEID, from=:FROM, to=:TO) =
  Interval(table, holeid, from, to)
