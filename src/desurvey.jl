# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    desurvey(collar, survey, intervals; method=:arc, convention=:auto)

Desurvey drill holes based on `collar`, `survey` and `intervals` tables
using a given step `method`. Optionally, specify a `convention` for the
dip angles.

## Methods

* `:arc` - spherical arc step
* `:tan` - simple tanget step

See https://help.seequent.com/Geo/2.1/en-GB/Content/drillholes/desurveying.htm

## Conventions

* `:auto`     - most frequent dip sign points downwards
* `:positive` - positive dip sign points downwards
* `:negative` - negative dip sign points downwards

## Example

```julia
julia> desurvey(collar, survey, [assay, lithology])
```
"""
function desurvey(collar, survey, intervals; method=:arc, convention=:auto)
  # sanity checks
  @assert method ∈ [:arc, :tan] "invalid step method"
  @assert convention ∈ [:auto, :positive, :negative] "invalid convention"

  # drillhole trajectories
  trajec = trajectories(survey, collar, method, convention)

  # attribute table
  pars = getcolnames(survey, method, convention)
  attrib = mergetables(intervals)
  fillxyz!(attrib, trajec, pars)

  DrillHole(attrib, trajec, pars)
end

function getcolnames(s, method, convention)
  m = method == :tan
  c = convention

  # get most common dip sign and assume it is downwards
  if c == :auto
    df = s.table
    c  = sum(sign.(df[!,s.dip])) > 0 ? :positive : :negative
  end

  inv = (c == :positive)

  (invdip=inv, tang=m)
end

function trajectories(survey, collar, method, convention)
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
  convention == :positive && (trajec.DIP *= -1)

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

# fill xyz for interval tables with from-to information
function fillxyz!(tab, trace, pars)
  # get column names
  tang = pars.tang
  f = pars.invdip ? -1 : 1

  # initialize coordinate columns with float values
  tab[!,:X] .= -9999.9999
  tab[!,:Y] .= -9999.9999
  tab[!,:Z] .= -9999.9999

  # get first hole name and get trace of that hole
  lastbhid = tab[1,:HOLEID]
  dht = trace[(trace[!,:HOLEID] .== lastbhid),:]

  # loop all intervals
  for i in 1:size(tab,1)
    # get hole name and mid point depth
    bhid, atx = tab[i,:HOLEID], tab[i,:FROM]+tab[i,:LENGTH]/2
    # update trace if hole name is different than previous one
    bhid != lastbhid && (dht = trace[(trace[!,:HOLEID] .== bhid),:])
    lastbhid = bhid
    # pass if no survey is available (WARN)
    size(dht, 1) == 0 && continue

    # get surveys bounding given depth
    b   = findbounds(dht[:,:AT],atx)
    d1x = atx-dht[b[1],:AT]

    if d1x == 0
      # if interval depth matches trace depth, get trace coordinates
      tab[i,:X] = dht[b[1],:X]
      tab[i,:Y] = dht[b[1],:Y]
      tab[i,:Z] = dht[b[1],:Z]
    else
      # if not, calculate coordinates increments dx,dy,dz
      d12 = dht[b[2],:AT]-dht[b[1],:AT]
      az1, dp1 = dht[b[1],:AZM], f*dht[b[1],:DIP]
      az2, dp2 = dht[b[2],:AZM], f*dht[b[2],:DIP]
      azx, dpx = b[1]==b[2] ? (az2, dp2) : weightedangs([az1,dp1],[az2,dp2],d12,d1x)
      dx,dy,dz = tang ? tanstep(az1,dp1,azx,dpx,d1x) : arcstep(az1,dp1,azx,dpx,d1x)

      # add increments dx,dy,dz to trace coordinates
      tab[i,:X] = dx + dht[b[1],:X]
      tab[i,:Y] = dy + dht[b[1],:Y]
      tab[i,:Z] = dz + dht[b[1],:Z]
    end
  end
  # check if some coordinate was not filled and return a warning if necessary
  filter!(row -> row.X != -9999.9999, tab)
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

# -----------------
# HELPER FUNCTIONS
# -----------------

# convert survey angles to 3D vector and vice versa
angs2vec(azm, dip) = (sind(azm)*cosd(-dip), cosd(azm)*cosd(-dip), sind(-dip))
vec2angs(x, y, z)  = (atand(x, y), -asind(z))

# average angle between two surveyed intervals
function weightedangs(angs1,angs2,d12,d1x)
  v1 = angs2vec(angs1...)
  v2 = angs2vec(angs2...)

  # weight according to distance to surveys
  p2   = d1x / d12
  p1   = 1 - p2
  v12  = @. p1*v1 + p2*v2

  vec2angs(v12...)
end

# find survey depths bounding given depth
function findbounds(depths, at)
  # get closest survey
  nearid = findmin(abs.(depths.-at))[2]
  nearest = depths[nearid]

  # check if depth is after last interval
  nearid == length(depths) && nearest < at && return (nearid,nearid)

  # return (previous, next) survey ids for given depth
  nearest == at && return (nearid, nearid)
  nearest >  at && return (nearid-1, nearid)
  nearest <  at && return (nearid, nearid+1)
end
