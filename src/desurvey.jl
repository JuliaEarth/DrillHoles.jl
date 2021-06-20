# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    desurvey(survey, collar, intervals; method=:arc, inputdip=:auto)

Desurvey drill holes based on `survey`, `collar` and `intervals` tables.
Optionally, specify a step `method` and a `inputdip` convention for the
dip angles.

## Step methods

* `:arc` - spherical arc step
* `:tan` - simple tanget step

See https://help.seequent.com/Geo/2.1/en-GB/Content/drillholes/desurveying.htm

## Dip conventions

* `:auto` - most frequent dip sign points downwards
* `:down` - positive dip sign points downwards
* `:up`   - positive dip sign points upwards
"""
function desurvey(survey, collar, intervals; method=:arc, inputdip=:auto)
  # sanity checks
  @assert method ∈ [:arc,:tan] "invalid step method"
  @assert inputdip ∈ [:auto,:down,:up] "invalid convention"

  # trajectory table
  trajec = trajectories(survey, collar, method, inputdip)

  # attribute table
  attrib = interleave(intervals)

  trajec, attrib
end

function trajectories(survey, collar, method, inputdip)
  # select relevant columns of survey table and
  # standardize column names to HOLEID, AT, AZM, DIP
  stable = select(DataFrame(survey.table),
                  survey.holeid => :HOLEID,
                  survey.at  => ByRow(Float64) => :AT,
                  survey.azm => ByRow(Float64) => :AZM,
                  survey.dip => ByRow(Float64) => :DIP)

  # select relevant columns of collar table and
  # standardize column names to HOLEID, X, Y, Z
  ctable = select(DataFrame(collar.table),
                  collar.holeid => :HOLEID,
                  collar.x => ByRow(Float64) => :X,
                  collar.y => ByRow(Float64) => :Y,
                  collar.z => ByRow(Float64) => :Z)

  # collar coordinates are at depth 0
  ctable[!,:AT] .= 0

  # join tables and sort by hole id and depth
  trajec = leftjoin(stable, ctable, on = [:HOLEID,:AT])
  sort!(trajec, [:HOLEID,:AT])

  # flip sign of dip angle if necessary
  inputdip == :down && (trajec.DIP *= -1)

  # choose a step method
  step = method == :arc ? arcstep : tanstep

  # relevant columns
  at, az, dp = trajec.AT, trajec.AZM, trajec.DIP
  x,   y,  z = trajec.X,  trajec.Y,   trajec.Z

  for i in 1:size(trajec, 1)
    # skip depth 0 where collar coordinates are already available
    at[i] == 0 && continue

    # compute increments dx, dy, dz
    az1, dp1   = az[i-1], dp[i-1]
    az2, dp2   = az[i],   dp[i]
    d12        = at[i] - at[i-1]
    dx, dy, dz = step(az1, dp1, az2, dp2, d12)

    # add increments to previous coordinates
    x[i] = x[i-1] + dx
    y[i] = y[i-1] + dy
    z[i] = z[i-1] + dz
  end

  trajec
end

function interleave(intervals)
  # standardize column names to HOLEID, FROM, TO
  tables = [rename(DataFrame(interval.table),
                   interval.holeid => :HOLEID,
                   interval.from   => :FROM,
                   interval.to     => :TO) for interval in intervals]

  # stack tables in order to see all variables
  table = vcat(tables..., cols = :union)

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

  # return inteleaved table with columns reordered
  select(DataFrame(rows), [:HOLEID,:FROM,:TO], Not([:HOLEID,:FROM,:TO]))
end

# -------------
# STEP METHODS
# -------------

function arcstep(az1, dp1, az2, dp2, d12)
  dp1, dp2 = (90-dp1), (90-dp2)
  DL = acos(cosd(dp2-dp1)-sind(dp1)*sind(dp2)*(1-cosd(az2-az1)))
  RF = DL!=0.0 ? 2*tan(DL/2)/DL : 1
  dx = 0.5*d12*(sind(dp1)*sind(az1)+sind(dp2)*sind(az2))*RF
  dy = 0.5*d12*(sind(dp1)*cosd(az1)+sind(dp2)*cosd(az2))*RF
  dz = 0.5*d12*(cosd(dp1)+cosd(dp2))*RF
  dx, dy, dz
end

function tanstep(az1, dp1, az2, dp2, d12)
  dp1 = (90-dp1)
  dx  = d12*sind(dp1)*sind(az1)
  dy  = d12*sind(dp1)*cosd(az1)
  dz  = d12*cosd(dp1)
  dx, dy, dz
end
