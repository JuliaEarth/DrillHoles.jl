# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    desurvey(collar, survey, intervals;
             step=:arc, indip=:auto, outdip=:down,
             len=nothing, geom=:cylinder, radius=1.0)

Desurvey drill holes based on `collar`, `survey` and `intervals` tables.
Optionally, specify a `step` method, an input dip angle convention `indip`
and an output dip angle convention `outdip`.

The option `len` can be used to composite samples to a given length, and
the option `geom` can be used to specify the geometry of each sample.

In the case of `:cylinder` geometry, the option `radius` can be used to
specify the radius of each cylinder.

## Step methods

* `:arc` - spherical arc step
* `:tan` - simple tanget step

See https://help.seequent.com/Geo/2.1/en-GB/Content/drillholes/desurveying.htm

## Dip conventions

### Input dip angle

* `:auto` - most frequent dip sign points downwards
* `:down` - positive dip points downwards
* `:up`   - positive dip points upwards

### Output dip angle

* `:down` - positive dip points downwards
* `:up`   - positive dip points upwards

## Output geometries

* `:cylinder` - geospatial data with cylinders
* `:point`    - geospatial data with points
* `:none`     - data frame with usual columns
"""
function desurvey(
  collar,
  survey,
  intervals;
  step=:arc,
  indip=:auto,
  outdip=:down,
  len=nothing,
  geom=:cylinder,
  radius=1.0
)
  # sanity checks
  @assert step ∈ [:arc, :tan] "invalid step method"
  @assert indip ∈ [:auto, :down, :up] "invalid input dip convention"
  @assert outdip ∈ [:down, :up] "invalid output dip convention"

  # pre-process input tables
  ctable, stable, itables = preprocess(collar, survey, intervals, indip)

  # combine all intervals into single table and
  # assign values to sub-intervals when possible
  itable = interleave(itables)

  # composite samples to a specified length
  ltable = isnothing(len) ? itable : composite(itable, len)

  # combine composites with survey table and
  # interpolate AZM and DIP angles
  ftable = position(ltable, stable)

  # combine samples with collar table and
  # compute Cartesian coordinates X, Y and Z
  result = locate(ftable, ctable, step)

  # post-process output table
  postprocess(result, outdip, geom, radius)
end

function preprocess(collar, survey, intervals, indip)
  # select relevant columns of collar table and
  # standardize column names to HOLEID, X, Y, Z
  ctable = let
    f1 = Rename(collar.holeid => :HOLEID, collar.x => :X, collar.y => :Y, collar.z => :Z)
    f2 = Select(:HOLEID, :X, :Y, :Z)
    f3 = DropMissing()
    f4 = Coerce(:X => Continuous, :Y => Continuous, :Z => Continuous)
    DataFrame(collar.table) |> (f1 → f2 → f3 → f4)
  end

  # select relevant columns of survey table and
  # standardize column names to HOLEID, AT, AZM, DIP
  stable = let
    f1 = Rename(survey.holeid => :HOLEID, survey.at => :AT, survey.azm => :AZM, survey.dip => :DIP)
    f2 = Select(:HOLEID, :AT, :AZM, :DIP)
    f3 = DropMissing()
    f4 = Coerce(:AT => Continuous, :AZM => Continuous, :DIP => Continuous)
    DataFrame(survey.table) |> (f1 → f2 → f3 → f4)
  end

  # flip sign of dip angle if necessary
  indip == :auto && (indip = dipguess(stable))
  indip == :down && (stable.DIP *= -1)

  # duplicate rows if hole id has a single row
  singles = []
  for hole in groupby(stable, :HOLEID)
    if size(hole, 1) == 1
      single = copy(hole)
      single.AT .+= 1
      push!(singles, single)
    end
  end
  stable = vcat(stable, singles...)

  # select all columns of interval tables and
  # standardize column names to HOLEID, FROM, TO
  itables = [
    rename(DataFrame(interval.table), interval.holeid => :HOLEID, interval.from => :FROM, interval.to => :TO) for
    interval in intervals
  ]

  ctable, stable, itables
end

dipguess(stable) = sum(sign, stable.DIP) > 0 ? :down : :up

function postprocess(table, outdip, geom, radius)
  # flip sign of dip angle if necessary
  outdip == :down && (table.DIP *= -1)

  # discard auxiliary SOURCE information
  samples = view(table, table.SOURCE .== :INTERVAL, Not(:SOURCE))

  # reorder columns for clarity
  cols = [:HOLEID, :FROM, :TO, :AT, :AZM, :DIP, :X, :Y, :Z]
  holes = select(samples, cols, Not(cols))

  # return data frame if no geometry is specified
  geom == :none && return holes

  # initialize result
  geotables = []

  # process each drillhole separately
  for dh in groupby(holes, :HOLEID)
    # skip if hole has no data
    isempty(dh) && continue

    # columns with data
    values = select(dh, Not(cols[2:end]))

    # coordinates of centroids
    coords = collect(zip(dh.X, dh.Y, dh.Z))

    # centroids as points
    points = Point.(coords)

    # geometry elements along hole
    domain = if geom == :cylinder
      CylindricalTrajectory(points, radius)
    else
      PointSet(points)
    end

    push!(geotables, geotable(domain, etable=values))
  end

  reduce(vcat, geotables)
end

function interleave(itables)
  # stack tables in order to see all variables
  table = vcat(itables..., cols=:union)

  # intialize rows of result table
  rows = []

  # process each drillhole separately
  for hole in groupby(table, :HOLEID)
    # save hole id for later
    holeid = first(hole.HOLEID)

    # find all possible depths
    depths = [hole.FROM; hole.TO] |> unique |> sort

    # loop over all sub-intervals
    for i in 2:length(depths)
      # current sub-interval
      from, to = depths[i - 1], depths[i]

      # intialize row with metadata
      row = Dict{Symbol,Any}(:HOLEID => holeid, :FROM => from, :TO => to)

      # find all intervals which contain sub-interval
      samples = filter(I -> I.FROM ≤ from && to ≤ I.TO, hole, view=true)

      # fill values when that is possible assuming homogeneity
      props = select(samples, Not([:HOLEID, :FROM, :TO]))
      for name in propertynames(props)
        ind = findfirst(!ismissing, props[!, name])
        val = isnothing(ind) ? missing : props[ind, name]
        row[name] = val
      end

      # save row and continue
      push!(rows, row)
    end
  end

  # concatenate rows
  DataFrame(rows)
end

function position(itable, stable)
  # copy table to avoid mutation
  interv = copy(itable)

  # depth equals to middle of interval
  interv[!, :AT] = (interv.FROM .+ interv.TO) ./ 2

  # register source of data for interval table
  interv[!, :SOURCE] .= :INTERVAL

  # join attributes and trajectory
  table = outerjoin(interv, stable, on=[:HOLEID, :AT])

  # register source of data for survey table
  table.SOURCE = coalesce.(table.SOURCE, :SURVEY)

  # initialize drillholes
  drillholes = []

  # process each drillhole separately
  for hole in groupby(table, :HOLEID)
    dh = sort(hole, :AT)

    # interpolate azm and dip angles
    interpolate!(dh, :AT, :AZM)
    interpolate!(dh, :AT, :DIP)

    push!(drillholes, dh)
  end

  # concatenate all drillholes
  attrib = reduce(vcat, drillholes)

  # fill FROM and TO of survey table
  # with AT (degenerate interval)
  for row in eachrow(attrib)
    ismissing(row.FROM) && (row.FROM = row.AT)
    ismissing(row.TO) && (row.TO = row.AT)
  end

  # drop missing type from complete columns
  dropmissing!(attrib, [:FROM, :TO, :AZM, :DIP])
end

# interpolate ycol from xcol assuming table is sorted
function interpolate!(table, xcol, ycol)
  xs = table[!, xcol]
  ys = table[!, ycol]
  is = findall(!ismissing, ys)
  if !isempty(is)
    itp = LinearItp(xs[is], ys[is], extrapolation_bc=LinearBC())
    @inbounds for i in 1:length(xs)
      ys[i] = itp(xs[i])
    end
  end
end

function locate(attrib, ctable, method)
  # collar coordinates are at depth 0
  ctableat = copy(ctable)
  ctableat[!, :AT] .= 0

  # join tables on hole id and depth
  table = leftjoin(attrib, ctableat, on=[:HOLEID, :AT])

  # choose a step method
  step = method == :arc ? arcstep : tanstep

  # initialize drillholes
  drillholes = []

  # process each drillhole separately
  for hole in groupby(table, :HOLEID)
    # sort intervals by depth
    dh = sort(hole, :AT)

    # view rows from survey table
    survey = view(dh, dh.SOURCE .== :SURVEY, :)

    # cannot interpolate a single row
    size(survey, 1) > 1 || continue

    # use step method to calculate coordinates on survey
    at, azm, dip = survey.AT, survey.AZM, survey.DIP
    x, y, z = survey.X, survey.Y, survey.Z
    @inbounds for i in 2:size(survey, 1)
      # compute increments dx, dy, dz
      az1, dp1 = azm[i - 1], dip[i - 1]
      az2, dp2 = azm[i], dip[i]
      d12 = at[i] - at[i - 1]
      dx, dy, dz = step(az1, dp1, az2, dp2, d12)

      # add increments to x, y, z
      x[i] = x[i - 1] + dx
      y[i] = y[i - 1] + dy
      z[i] = z[i - 1] + dz
    end

    # interpolate coordinates linearly on intervals
    interpolate!(dh, :AT, :X)
    interpolate!(dh, :AT, :Y)
    interpolate!(dh, :AT, :Z)

    push!(drillholes, dh)
  end

  # concatenate drillhole trajectories
  result = reduce(vcat, drillholes)

  # drop missing type from complete columns
  dropmissing!(result, [:X, :Y, :Z])
end

# -------------
# STEP METHODS
# -------------

# assumes positive dip points upwards
function arcstep(az1, dp1, az2, dp2, d12)
  dp1, dp2 = (90.0 - dp1), (90.0 - dp2)
  DL = acos(cosd(dp2 - dp1) - sind(dp1) * sind(dp2) * (1 - cosd(az2 - az1)))
  RF = DL ≈ 0.0 ? 1.0 : 2 * tan(DL / 2) / DL
  dx = 0.5 * d12 * (sind(dp1) * sind(az1) + sind(dp2) * sind(az2)) * RF
  dy = 0.5 * d12 * (sind(dp1) * cosd(az1) + sind(dp2) * cosd(az2)) * RF
  dz = 0.5 * d12 * (cosd(dp1) + cosd(dp2)) * RF
  dx, dy, dz
end

# assumes positive dip points upwards
function tanstep(az1, dp1, az2, dp2, d12)
  dp1 = (90.0 - dp1)
  dx = d12 * sind(dp1) * sind(az1)
  dy = d12 * sind(dp1) * cosd(az1)
  dz = d12 * cosd(dp1)
  dx, dy, dz
end
