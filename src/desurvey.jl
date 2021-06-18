# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    desurvey(collar, survey, intervals; method=:arc, convention=:auto)

Desurvey drill holes based on `collar`, `survey` and `intervals` tables
using a given `method`. Optionally, specify a `convention` for the dip
angles.

## Methods

* `:arc`     - spherical arc approximation
* `:tangent` - raw tanget approximation

See https://help.seequent.com/Geo/2.1/en-GB/Content/drillholes/desurveying.htm

## Conventions

* `:auto`     - assumes that the most frequent dip sign points downwards
* `:positive` - positive dip sign points downwards
* `:negative` - negative dip sign points downwards

## Example

```julia
julia> desurvey(collar, survey, [assay, lithology])
```
"""
function desurvey(collar::Collar, survey::Survey, intervals;
                  method=:arc, convention=:auto)
  # pre process information
  pars = getcolnames(survey, intervals, method, convention)

  # compute drillhole trajectories
  trace = trajectories(survey, collar)
  fillxyz!(trace, pars)

  # merge interval tables
  table = mergetables(intervals, pars)
  fillxyz!(table, trace, pars)

  DrillHole(table, trace, pars)
end

function getcolnames(s, i, method, convention)
  f = first(i).from
  t = first(i).to
  m = method == :tangent
  c = convention

  # get most common dip sign and assume it is downwards
  if c == :auto
    df = s.table
    c  = sum(sign.(df[!,s.dip])) > 0 ? :positive : :negative
  end

  inv  = (c == :positive)

  (holeid=s.holeid, at=s.at, azm=s.azm, dip=s.dip, from=f, to=t, invdip=inv, tang=m)
end

function trajectories(survey, collar)
  # select relevant columns of survey table
  stable = select(DataFrame(survey.table),
                  survey.holeid,
                  survey.at,
                  survey.azm,
                  survey.dip)

  # rename collar columns to match survey columns if necessary
  # and fix coordinates types to double floating point precision
  ctable = select(DataFrame(collar.table),
                  collar.holeid => survey.holeid,
                  collar.x => ByRow(Float64) => :X,
                  collar.y => ByRow(Float64) => :Y,
                  collar.z => ByRow(Float64) => :Z)

  # assign collar coordinates to initial survey point
  ctable[!,survey.at] .= 0

  # join tables and sort by hole id and at
  cols  = [survey.holeid, survey.at]
  trace = leftjoin(stable, ctable, on = cols)
  sort!(trace, cols)
end

function fillxyz!(trace, pars)
  # get column names
  at, az, dp, tang = pars.at, pars.azm, pars.dip, pars.tang
  f = pars.invdip ? -1 : 1

  # loop trace file
  for i in 1:size(trace,1)
    # pass depth 0 where collar coordinates are already available
    trace[i,at] == 0 && continue

    # get distances and angles; return increments dx,dy,dz
    d12      = trace[i,at] - trace[i-1,at]
    az1, dp1 = trace[i-1,az], f*trace[i-1,dp]
    az2, dp2 = trace[i,az], f*trace[i,dp]
    dx,dy,dz = tang ? tangentmethod(az1,dp1,az2,dp2,d12) : arcmethod(az1,dp1,az2,dp2,d12)

    # add increments dx,dy,dz to previous coordinates
    trace[i,:X] = dx + trace[i-1,:X]
    trace[i,:Y] = dy + trace[i-1,:Y]
    trace[i,:Z] = dz + trace[i-1,:Z]
  end
end

# fill xyz for interval tables with from-to information
function fillxyz!(tab, trace, pars)
  # get column names
  bh, at, az, dp, tang = pars.holeid, pars.at, pars.azm, pars.dip, pars.tang
  from, to = pars.from, pars.to
  f = pars.invdip ? -1 : 1

  # initialize coordinate columns with float values
  tab[!,:X] .= -9999.9999
  tab[!,:Y] .= -9999.9999
  tab[!,:Z] .= -9999.9999

  # get first hole name and get trace of that hole
  lastbhid = tab[1,bh]
  dht = trace[(trace[!,bh] .== lastbhid),:]

  # loop all intervals
  for i in 1:size(tab,1)
    # get hole name and mid point depth
    bhid, atx = tab[i,bh], tab[i,from]+tab[i,:LENGTH]/2
    # update trace if hole name is different than previous one
    bhid != lastbhid && (dht = trace[(trace[!,bh] .== bhid),:])
    lastbhid = bhid
    # pass if no survey is available (WARN)
    size(dht, 1) == 0 && continue

    # get surveys bounding given depth
    b   = findbounds(dht[:,at],atx)
    d1x = atx-dht[b[1],at]

    if d1x == 0
      # if interval depth matches trace depth, get trace coordinates
      tab[i,:X] = dht[b[1],:X]
      tab[i,:Y] = dht[b[1],:Y]
      tab[i,:Z] = dht[b[1],:Z]
    else
      # if not, calculate coordinates increments dx,dy,dz
      d12 = dht[b[2],at]-dht[b[1],at]
      az1, dp1 = dht[b[1],az], f*dht[b[1],dp]
      az2, dp2 = dht[b[2],az], f*dht[b[2],dp]
      azx, dpx = b[1]==b[2] ? (az2, dp2) : weightedangs([az1,dp1],[az2,dp2],d12,d1x)
      dx,dy,dz = tang ? tangentmethod(az1,dp1,azx,dpx,d1x) : arcmethod(az1,dp1,azx,dpx,d1x)

      # add increments dx,dy,dz to trace coordinates
      tab[i,:X] = dx + dht[b[1],:X]
      tab[i,:Y] = dy + dht[b[1],:Y]
      tab[i,:Z] = dz + dht[b[1],:Z]
    end
  end
  # check if some coordinate was not filled and return a warning if necessary
  filter!(row -> row.X != -9999.9999, tab)
end

# --------------------
# DESURVEYING METHODS
# --------------------

function arcmethod(az1, dp1, az2, dp2, d12)
  dp1, dp2 = (90-dp1), (90-dp2)

  DL = acos(cosd(dp2-dp1)-sind(dp1)*sind(dp2)*(1-cosd(az2-az1)))
  RF = DL!=0.0 ? 2*tan(DL/2)/DL : 1

  dx = 0.5*d12*(sind(dp1)*sind(az1)+sind(dp2)*sind(az2))*RF
  dy = 0.5*d12*(sind(dp1)*cosd(az1)+sind(dp2)*cosd(az2))*RF
  dz = 0.5*d12*(cosd(dp1)+cosd(dp2))*RF
  dx, dy, dz
end

function tangentmethod(az1, dp1, az2, dp2, d12)
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
angs2vec(az,dp) = [sind(az)*cosd(-dp), cosd(az)*cosd(-dp), sind(-dp)]
vec2angs(i,j,k) = [atand(i,j), -asind(k)]

# average angle between two surveyed intervals
function weightedangs(angs1,angs2,d12,d1x)
  # angle to vectors
  v1 = angs2vec(angs1...)
  v2 = angs2vec(angs2...)

  # weight average vector according to distance to surveys
  p2   = d1x/d12
  p1   = 1-p2
  v12  = v1*p1 + v2*p2
  v12 /= sqrt(sum(abs2,v12))

  # convert average vector to survey angles and return it
  azm, dip = vec2angs(v12...)
  azm, dip
end

# find survey depths bounding given depth
function findbounds(depths::AbstractArray, at)
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
