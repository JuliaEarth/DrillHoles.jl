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
    Collar(table; [holeid], [x], [y], [z])

The collar `table` stores the `x`, `y`, `z` coordinates
(usually in meters) of the head of the drill holes with
specified `holeid`.

Common column names are searched in the `table` when keyword
arguments are ommitted.

## Examples

```julia
Collar(table, holeid="BHID", x="EASTING", y="NORTHING")
Collar(table, x="XCOLLAR", y="YCOLLAR", z="ZCOLLAR")
```

See also [`Survey`](@ref), [`Interval`](@ref).
"""
struct Collar{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  x::Symbol
  y::Symbol
  z::Symbol

  function Collar{𝒯}(table, holeid, x, y, z) where {𝒯}
    assertspec(table, [holeid, x, y, z])
    assertreal(table, [x, y, z])
    new(table, holeid, x, y, z)
  end
end

Collar(table; holeid=defaultid(table), x=defaultx(table), y=defaulty(table), z=defaultz(table)) =
  Collar{typeof(table)}(table, Symbol(holeid), Symbol(x), Symbol(y), Symbol(z))

required(table::Collar) = (table.holeid, table.x, table.y, table.z)

"""
    Survey(table; [holeid], [at], [azm], [dip])

The survey `table` stores the `azm` and `dip` angles
(usually in degrees) `at` each depth (usually in meters)
along drill holes with specified `holeid`.

Common column names are searched in the `table` when keyword
arguments are ommitted.

## Examples

```julia
Survey(table, holeid="BHID", at="DEPTH")
Survey(table, azm="AZIMUTH")
```

See also [`Collar`](@ref), [`Interval`](@ref).
"""
struct Survey{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  at::Symbol
  azm::Symbol
  dip::Symbol

  function Survey{𝒯}(table, holeid, at, azm, dip) where {𝒯}
    assertspec(table, [holeid, at, azm, dip])
    assertreal(table, [at, azm, dip])
    new(table, holeid, at, azm, dip)
  end
end

Survey(table; holeid=defaultid(table), at=defaultat(table), azm=defaultazm(table), dip=defaultdip(table)) =
  Survey{typeof(table)}(table, Symbol(holeid), Symbol(at), Symbol(azm), Symbol(dip))

required(table::Survey) = (table.holeid, table.at, table.azm, table.dip)

"""
    Interval(table; [holeid], [from], [to])

The interval `table` stores the interval `from` a given
depth `to` another greater depth (usually in meters), along
drill holes with specified `holeid`. Besides the intervals,
the `table` stores measurements of variables such as grades,
mineralization domains, geological interpretations, etc.

Common column names are searched in the `table` when keyword
arguments are ommitted.

## Examples

```julia
Interval(table, holeid="BHID", from="START", to="FINISH")
Interval(table, from="BEGIN", to="END")
```

See also [`Collar`](@ref), [`Survey`](@ref).
"""
struct Interval{𝒯} <: MiningTable
  table::𝒯
  holeid::Symbol
  from::Symbol
  to::Symbol

  function Interval{𝒯}(table, holeid, from, to) where {𝒯}
    assertspec(table, [holeid, from, to])
    assertreal(table, [from, to])
    new(table, holeid, from, to)
  end
end

Interval(table; holeid=defaultid(table), from=defaultfrom(table), to=defaultto(table)) =
  Interval{typeof(table)}(table, Symbol(holeid), Symbol(from), Symbol(to))

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
function default(table, names, kwarg)
  cols = Tables.columns(table)
  available = Tables.columnnames(cols)
  augmented = augment(names)
  for name in augmented
    if name ∈ available
      return name
    end
  end
  ag = join(augmented, ", ", " and ")
  av = join(available, ", ", " and ")
  throw(ArgumentError("""\n
                      None of the column names $ag was found in table.

                      Please specify $kwarg=... explicitly.

                      Available names: $av.
                      """))
end

defaultid(table) = default(table, [:holeid, :bhid], :holeid)
defaultx(table) = default(table, [:x, :xcollar, :easting], :x)
defaulty(table) = default(table, [:y, :ycollar, :northing], :y)
defaultz(table) = default(table, [:z, :zcollar, :elevation], :z)
defaultazm(table) = default(table, [:azimuth, :azm, :brg], :azm)
defaultdip(table) = default(table, [:dip], :dip)
defaultat(table) = default(table, [:at, :depth], :at)
defaultfrom(table) = default(table, [:from], :from)
defaultto(table) = default(table, [:to], :to)

function augment(names)
  snames = string.(names)
  anames = [snames; uppercasefirst.(snames); uppercase.(snames)]
  Symbol.(unique(anames))
end

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

function assertreal(table, names)
  cols = Tables.columns(table)
  for name in names
    x = Tables.getcolumn(cols, name)
    T = eltype(x)
    if !(T <: Union{Real,Missing})
      throw(ArgumentError("""\n
      Column $name should contain real values,
      but it currently has values of type $T.
      Please fix the type before trying to load
      the data into the mining table.
      """))
    end
  end
end
