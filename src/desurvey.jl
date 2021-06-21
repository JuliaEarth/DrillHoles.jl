# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    desurvey(survey, collar, intervals; step=:arc, inputdip=:auto)

Desurvey drill holes based on `survey`, `collar` and `intervals` tables.
Optionally, specify a `step` method and a `inputdip` and `ouputdip`
convention for the dip angles.

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
"""
function desurvey(survey, collar, intervals;
                  step=:arc, inputdip=:auto, outputdip=:up)
  # sanity checks
  @assert step ∈ [:arc,:tan] "invalid step method"
  @assert inputdip ∈ [:auto,:down,:up] "invalid input dip convention"
  @assert outputdip ∈ [:down,:up] "invalid output dip convention"

  # pre-process input tables
  stable, ctable, itables = preprocess(survey, collar, intervals, inputdip)

  # combine all intervals into single table and
  # assign values to sub-intervals when possible
  itable = interleave(itables)

  # combine intervals with survey table and
  # interpolate AZM and DIP angles
  attrib = position(itable, stable)

  # combine attributes with collar table and
  # compute Cartesian coordinates X, Y and Z
  result = locate(attrib, ctable, step)

  # post-process output table
  postprocess(result, outputdip)
end

function preprocess(survey, collar, intervals, inputdip)
  # select relevant columns of survey table and
  # standardize column names to HOLEID, AT, AZM, DIP
  stable = select(DataFrame(survey.table),
                  survey.holeid => :HOLEID,
                  survey.at  => ByRow(Float64) => :AT,
                  survey.azm => ByRow(Float64) => :AZM,
                  survey.dip => ByRow(Float64) => :DIP)

  # flip sign of dip angle if necessary
  inputdip == :auto && (inputdip = dipguess(stable))
  inputdip == :down && (stable.DIP *= -1)

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

  # select relevant columns of collar table and
  # standardize column names to HOLEID, X, Y, Z
  ctable = select(DataFrame(collar.table),
                  collar.holeid => :HOLEID,
                  collar.x => ByRow(Float64) => :X,
                  collar.y => ByRow(Float64) => :Y,
                  collar.z => ByRow(Float64) => :Z)

  # select all columns of interval tables and
  # standardize column names to HOLEID, FROM, TO
  itables = [rename(DataFrame(interval.table),
                    interval.holeid => :HOLEID,
                    interval.from   => :FROM,
                    interval.to     => :TO) for interval in intervals]

  stable, ctable, itables
end

dipguess(stable) = sum(sign, stable.DIP) > 0 ? :down : :up

function postprocess(result, outputdip)
  # flip sign of dip angle if necessary
  outputdip == :down && (result.DIP *= -1)

  # reorder columns for clarity
  cols = [:HOLEID,:FROM,:TO,:AT,:AZM,:DIP,:X,:Y,:Z]
  select(result, cols, Not(cols))
end

function interleave(itables)
  # stack tables in order to see all variables
  table = vcat(itables..., cols = :union)

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
      from, to = depths[i-1], depths[i]

      # intialize row with metadata
      row = Dict{Symbol,Any}(:HOLEID => holeid, :FROM => from, :TO => to)

      # find all intervals which contain sub-interval
      samples = filter(I -> I.FROM ≤ from && to ≤ I.TO, hole, view = true)

      # fill values when that is possible assuming homogeneity
      props = select(samples, Not([:HOLEID,:FROM,:TO]))
      for name in propertynames(props)
        ind = findfirst(!ismissing, props[!,name])
        val = isnothing(ind) ? missing : props[ind,name]
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
  # depth equals to middle of interval
  interv = copy(itable)
  interv[!,:AT] = (interv.FROM .+ interv.TO) ./ 2

  # join attributes and trajectory
  table = outerjoin(interv, stable, on = [:HOLEID,:AT])

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
    ismissing(row.TO)   && (row.TO   = row.AT)
  end

  # drop missing type from complete columns
  dropmissing!(attrib, [:FROM,:TO,:AZM,:DIP])
end

# interpolate ycol from xcol assuming table is sorted
function interpolate!(table, xcol, ycol)
  xs  = table[!,xcol]
  ys  = table[!,ycol]
  is  = findall(!ismissing, ys)
  itp = LinearItp(xs[is], ys[is], extrapolation_bc=LinearBC())
  @inbounds for i in 1:length(xs)
    ys[i] = itp(xs[i])
  end
end

function locate(attrib, ctable, method)
  # collar coordinates are at depth 0
  ctableat = copy(ctable)
  ctableat[!,:AT] .= 0

  # join tables on hole id and depth
  table = leftjoin(attrib, ctableat, on = [:HOLEID,:AT])

  # choose a step method
  step = method == :arc ? arcstep : tanstep

  # initialize trajectories
  trajecs = []

  # process each drillhole separately
  for hole in groupby(table, :HOLEID)
    # sort intervals by depth
    trajec = sort(hole, :AT)

    # relevant columns
    at, azm, dip = trajec.AT, trajec.AZM, trajec.DIP
    x,  y,   z   = trajec.X,  trajec.Y,   trajec.Z

    # loop over intervals
    @inbounds for i in 2:size(trajec, 1)
      # compute increments dx, dy, dz
      az1, dp1   = azm[i-1], dip[i-1]
      az2, dp2   = azm[i],   dip[i]
      d12        = at[i] - at[i-1]
      dx, dy, dz = step(az1, dp1, az2, dp2, d12)

      # add increments to previous coordinates
      x[i] = x[i-1] + dx
      y[i] = y[i-1] + dy
      z[i] = z[i-1] + dz
    end

    push!(trajecs, trajec)
  end

  # concatenate drillhole trajectories
  drillholes = reduce(vcat, trajecs)

  # drop missing type from complete columns
  dropmissing!(drillholes, [:X,:Y,:Z])
end

# -------------
# STEP METHODS
# -------------

# assumes positive dip points upwards
function arcstep(az1, dp1, az2, dp2, d12)
  dp1, dp2 = (90-dp1), (90-dp2)
  DL = acos(cosd(dp2-dp1)-sind(dp1)*sind(dp2)*(1-cosd(az2-az1)))
  RF = DL != 0.0 ? 2*tan(DL/2)/DL : 1.0
  dx = 0.5*d12*(sind(dp1)*sind(az1)+sind(dp2)*sind(az2))*RF
  dy = 0.5*d12*(sind(dp1)*cosd(az1)+sind(dp2)*cosd(az2))*RF
  dz = 0.5*d12*(cosd(dp1)+cosd(dp2))*RF
  dx, dy, dz
end

# assumes positive dip points upwards
function tanstep(az1, dp1, az2, dp2, d12)
  dp1 = (90-dp1)
  dx  = d12*sind(dp1)*sind(az1)
  dy  = d12*sind(dp1)*cosd(az1)
  dz  = d12*cosd(dp1)
  dx, dy, dz
end
