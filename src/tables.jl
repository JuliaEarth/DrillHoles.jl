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

"""
    selection(table)

Return the subtable of mining `table` with required columns.
"""
selection(t::MiningTable) = t.table |> Select(required(t))

# -----------------
# TABLES INTERFACE
# -----------------

Tables.istable(::Type{<:MiningTable}) = true

Tables.rowaccess(::Type{<:MiningTable}) = true

Tables.columnaccess(::Type{<:MiningTable}) = true

Tables.rows(t::MiningTable) = Tables.rows(selection(t))

Tables.columns(t::MiningTable) = Tables.columns(selection(t))

Tables.columnnames(t::MiningTable) = Tables.columnnames(selection(t))

# -----------
# IO METHODS
# -----------

Base.show(io::IO, mime::MIME"text/plain", t::MiningTable) = _show(io, mime, t)
Base.show(io::IO, mime::MIME"text/html", t::MiningTable) = _show(io, mime, t)
_show(io, mime, t) = show(io, mime, selection(t))

# ----------------
# IMPLEMENTATIONS
# ----------------

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

  function Survey{𝒯}(table, holeid, at, azm, dip) where {𝒯}
    assertspec(table, [holeid, at, azm, dip])
    ctable = coercecont(table, [at, azm, dip])
    new(ctable, holeid, at, azm, dip)
  end
end

Survey(table; holeid=defaultid(table), at=defaultat(table), azm=defaultazm(table), dip=defaultdip(table)) =
  Survey{typeof(table)}(table, holeid, at, azm, dip)

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

  function Collar{𝒯}(table, holeid, x, y, z) where {𝒯}
    assertspec(table, [holeid, x, y, z])
    ctable = coercecont(table, [x, y, z])
    new(ctable, holeid, x, y, z)
  end
end

Collar(table; holeid=defaultid(table), x=defaultx(table), y=defaulty(table), z=defaultz(table)) =
  Collar{typeof(table)}(table, holeid, x, y, z)

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

  function Interval{𝒯}(table, holeid, from, to) where {𝒯}
    assertspec(table, [holeid, from, to])
    ctable = coercecont(table, [from, to])
    new(ctable, holeid, from, to)
  end
end

Interval(table; holeid=defaultid(table), from=defaultfrom(table), to=defaultto(table)) =
  Interval{typeof(table)}(table, holeid, from, to)

required(table::Interval) = (table.holeid, table.from, table.to)

function selection(t::Interval)
  all = Tables.columnnames(t.table)
  req = collect(required(t))
  not = setdiff(all, req)
  t.table |> Select([req; not])
end

# ---------
# DEFAULTS
# ---------

# helper function to find default column names
# from a list of candidate names
function default(table, names)
  cols = Tables.columns(table)
  avail = Tables.columnnames(cols)
  for name in names
    if name ∈ avail
      return name
    end
  end
  ns = join(names, ", ", " and ")
  av = join(avail, ", ", " and ")
  throw(ArgumentError("""\n
                      None of the names $ns was found in table.
                      Please specify name explicitly. Available names are $av.
                      """))
end

defaultid(table) = default(table, [:HOLEID, :BHID, :holeid, :bhid])
defaultx(table) = default(table, [:X, :XCOLLAR, :x, :xcollar])
defaulty(table) = default(table, [:Y, :YCOLLAR, :y, :ycollar])
defaultz(table) = default(table, [:Z, :ZCOLLAR, :z, :zcollar])
defaultazm(table) = default(table, [:AZM, :BRG, :azm, :brg])
defaultdip(table) = default(table, [:DIP, :dip])
defaultat(table) = default(table, [:AT, :at])
defaultfrom(table) = default(table, [:FROM, :from])
defaultto(table) = default(table, [:TO, :to])

# -----------
# ASSERTIONS
# -----------

function assertspec(table, names)
  cols = Tables.columns(table)
  avail = Tables.columnnames(cols)
  if !(names ⊆ avail)
    wrong = join(setdiff(names, avail), ", ", " and ")
    throw(ArgumentError("None of the names $wrong was found in the table."))
  end
end

function coercecont(table, snames)
  cols = Tables.columns(table)
  names = Tables.columnnames(cols)
  newcols = map(names) do name
    x = Tables.getcolumn(cols, name)
    if name in snames
      DataScienceTraits.coerce(Continuous, x)
    else
      x
    end
  end
  (; zip(names, newcols)...) |> Tables.materializer(table)
end
