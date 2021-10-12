# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    MiningTable

A table from the mining industry (e.g. survey, collar, interval).
"""
abstract type MiningTable end

"""
    required(table)

Return the required columns of mining `table`.
"""
function required end

function Base.show(io::IO, mime::MIME"text/plain", t::MiningTable)
  df  = DataFrame(t.table)
  sub = df[!,collect(required(t))]
  show(io, mime, sub)
end

"""
    Survey(table; [holeid], [at], [azm], [dip])

Survey table and its main columns fields.
"""
struct Survey{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  at::Symbol
  azm::Symbol
  dip::Symbol
end

Survey(table;
       holeid = defaultid(table),
       at     = defaultat(table),
       azm    = defaultazm(table),
       dip    = defaultdip(table)) =
  Survey(table, holeid, at, azm, dip)

required(table::Survey) = (table.holeid, table.at, table.azm, table.dip)

"""
    Collar(table; [holeid], [x], [y], [z])

Collar table and its main column fields.
"""
struct Collar{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  x::Symbol
  y::Symbol
  z::Symbol
end

Collar(table;
       holeid = defaultid(table),
       x      = defaultx(table),
       y      = defaulty(table),
       z      = defaultz(table)) =
  Collar(table, holeid, x, y, z)

required(table::Collar) = (table.holeid, table.x, table.y, table.z)

"""
    Interval(table; [holeid], [from], [to])

Interval table and its main column fields.
"""
struct Interval{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  from::Symbol
  to::Symbol
end

Interval(table;
         holeid = defaultid(table),
         from   = defaultfrom(table),
         to     = defaultto(table)) =
  Interval(table, holeid, from, to)

required(table::Interval) = (table.holeid, table.from, table.to)

function Base.show(io::IO, mime::MIME"text/plain", t::Interval)
  df  = DataFrame(t.table)
  req = collect(required(t))
  all = [df[!,req] df[!,Not(req)]]
  show(io, mime, all)
end

# helper function to find default column names
# from a list of candidate names
function default(table, names)
  for name in names
    if name ∈ Tables.columnnames(table)
      return name
    end
  end
  ns = join(names, ", ", " and ")
  throw(ArgumentError("None of the names $ns was found in table. Please specify name explicitly."))
end

defaultid(table)   = default(table, [:HOLEID,:BHID,:holeid,:bhid])
defaultx(table)    = default(table, [:X,:XCOLLAR,:x,:xcollar])
defaulty(table)    = default(table, [:Y,:YCOLLAR,:y,:ycollar])
defaultz(table)    = default(table, [:Z,:ZCOLLAR,:z,:zcollar])
defaultazm(table)  = default(table, [:AZM,:BRG,:azm,:brg])
defaultdip(table)  = default(table, [:DIP,:dip])
defaultat(table)   = default(table, [:AT,:at])
defaultfrom(table) = default(table, [:FROM,:from])
defaultto(table)   = default(table, [:TO,:to])
