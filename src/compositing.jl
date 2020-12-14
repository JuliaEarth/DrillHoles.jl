
"""
  composite(dh::DrillHole; interval=1.0, zone=nothing, mode=:equalcomp,
  mincomp=0.5, gap=0.001)

Composite a drill hole object considering the given parameters. Outputs a
new composited `DrillHole` object.

## Parameters:

* `dh`       - desurveyed drill hole
* `interval` - composite length
* `zone`     - zone column name; if considered, intervals composited together
  must have the same zone value
* `mode`     - method for compositing (see below the options available)
* `mincomp`  - minimum composite lenght; smaller intervals are discarded.
* `gap`      - two intervals are not composited together if the spacing between
  them exceeds the `gap` value

## Methods:

* `:equalcomp` - seeks to create composites with the exact `interval` length;
  borders are discarded if have length below `mincomp`. Max composite length = `interval`
* `:nodiscard` - composite lengths are defined seeking to include all possible
  intervals with length above `mincomp`. Max composite length = 1.5*`interval`
"""
function composite(dhf::DrillHole; interval::Number=1.0,
  zone=nothing, mode=:equalcomp, mincomp=0.5, gap=0.001)

  dh = copy(dhf.table)
  pars = dhf.pars
  bh, from, to = pars.holeid, pars.from, pars.to

  # get groups to composite
  gps = []; c = 1
  for i in 1:size(dh,1)
    i == 1 && push!(gps,c)
    i == 1 && continue

    t1 = (dh[i-1,to] - dh[i,from]) > gap
    t2 = dh[i-1,bh] != dh[i,bh]
    t3 = zone == nothing ? false : dh[i-1,zone] != dh[i,zone]
    (t1 || t2 || t3) && (c += 1)
    push!(gps,c)
  end

  maincols = Symbol.([bh,from,to,:LENGTH])
  zone != nothing && push!(maincols,Symbol(zone))
  num = eltype.(eachcol(dh)) .<: Union{Missing, Number}
  numcols = setdiff(Symbol.(names(dh))[num],maincols)
  numcols = setdiff(numcols,[:X,:Y,:Z])
  select!(dh,union(maincols,numcols))

  comps = DataFrame() #copy(first(dh,0))
  dh[!,"_GP_"] = gps

  for dft in groupby(dh,:_GP_)
    len = sum(dft[!,:LENGTH])
  	len < mincomp && continue
    dfa = DataFrame()

    if mode == :nodiscard
      div = len/interval
      if div <= 1 || isinteger(div)
        nbint = ceil(Int,div)
      else
        prenbint = [floor(Int,div), ceil(Int,div)]
        closest = argmin([abs(interval-len/x) for x in prenbint])
        nbint = prenbint[closest]
        closest ==1 && len/nbint < mincomp && (nbint = prenbint[2])
      end

      intlen = nbint > 1 ? len/nbint : len
      minfrom = minimum(dft[!,:FROM])
      maxto = maximum(dft[!,:TO])

      dfa[!,from] = collect(minfrom:intlen:maxto)[1:nbint]
      dfa[!,to] = dfa[!,from] .+ intlen
      dfa[!,bh] .= dft[1,bh]
      dfa[!,:LENGTH] .= intlen
      zone != nothing && (dfa[!,zone] .= dft[1,zone])
    else
      div = len/interval
      nbint = floor(Int,div)
      last = (len-nbint*interval)
      last >= mincomp && (nbint += 1)
      last < mincomp && (last = interval)

      minfrom = minimum(dft[!,:FROM])
      maxto = maximum(dft[!,:TO])

      dfa[!,from] = collect(minfrom:interval:maxto)[1:nbint]
      dfa[!,to] = dfa[!,from] .+ interval
      dfa[end,to] -= (interval-last)
      dfa[!,bh] .= dft[1,bh]
      dfa[!,:LENGTH] = dfa[!,to] - dfa[!,from]
      zone != nothing && (dfa[!,zone] .= dft[1,zone])
    end

    # initialize new cols
    for col in numcols
      dfa[!,col] .= -9999.9999
    end
    allowmissing!(dfa, numcols)

    # averaging numeric values
    wcols = union(Symbol.([from,to]), numcols)
    for i in 1:size(dfa,1)
      f, t = dfa[i,from], dfa[i,to]
      vals = dft[(dft[!,to] .> f) .& (dft[!,from] .< t), wcols]
      size(vals,1) == 0 && (dfa[i,col] = missing)
      size(vals,1) == 0 && continue
      vals[1,from]=f
      vals[end,to]=t
      leng = vals[:,to]-vals[:,from]
      for col in numcols
        ivalid = findall(!ismissing,vals[!,col])
        n = length(ivalid)
        wgt = n >= 1 ? weights(leng[ivalid]) : missing
        n == 0 && (dfa[i,col] = missing)
        n == 1 && (dfa[i,col] = vals[1,col])
        n > 1 && (dfa[i,col] = mean(vals[ivalid,col], wgt))
      end
    end
    comps = vcat(comps, dfa, cols=:union)
  end

  fillxyz!(comps, dhf.trace, pars)
  DrillHole(comps, dhf.trace, pars, dhf.warns)
end
