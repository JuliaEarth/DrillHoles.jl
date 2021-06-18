# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    composite(dh::DrillHole; interval=1.0, zone=nothing, mode=:equalcomp, mincomp=0.5, gap=0.001)

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
function composite(dhf::DrillHole; interval::Number=1.0, zone=nothing,
                   mode=:equalcomp, mincomp=0.5, gap=0.001)
  # initial assertions
  @assert mode ∈ [:equalcomp, :nodiscard] "invalid method"
  @assert mincomp <= interval "mincomp must be <= interval"

  # copy drill hole and get column names
  dh   = copy(dhf.table)
  pars = dhf.pars
  bh, from, to = pars.holeid, pars.from, pars.to

  # get group of intervals to composite within
  gps = []; c = 1
  for i in 1:size(dh,1)
    i == 1 && push!(gps,c)
    i == 1 && continue

    # check gaps, holes and zones to create/separate different groups
    t1 = (dh[i-1,to] - dh[i,from]) > gap
    t2 = dh[i-1,bh] != dh[i,bh]
    t3 = isnothing(zone) ? false : !isequal(dh[i-1,zone], dh[i,zone])
    (t1 || t2 || t3) && (c += 1)
    push!(gps,c)
  end

  # get numeric columns to composite and retain main columns
  maincols = Symbol.([bh,from,to,:LENGTH])
  zone != nothing && push!(maincols,Symbol(zone))
  num     = eltype.(eachcol(dh)) .<: Union{Missing, Number}
  numcols = setdiff(Symbol.(names(dh))[num],maincols)
  numcols = setdiff(numcols,[:X,:Y,:Z])
  select!(dh,union(maincols,numcols))

  # output table and auxiliary grouping variable
  comps = DataFrame()
  dh[!,"_GP_"] = gps

  # loop all grouped intervals
  for grp in groupby(dh,:_GP_)
    # get group length and ignore it if below mincomp; create composited group table
    len = sum(grp[!,:LENGTH])
    len < mincomp && continue
    tab = DataFrame()

    # get composited intervals for :nodiscard compositing mode
    if mode == :nodiscard
      div = len/interval
      if div <= 1 || isinteger(div)
        nbint = ceil(Int,div)
      else
        prenbint = [floor(Int,div), ceil(Int,div)]
        closest  = argmin([abs(interval-len/x) for x in prenbint])
        nbint    = prenbint[closest]
        closest == 1 && len/nbint < mincomp && (nbint = prenbint[2])
      end

      intlen  = nbint > 1 ? len/nbint : len
      minfrom = minimum(grp[!,:FROM])
      maxto   = maximum(grp[!,:TO])

      tab[!,from]     = collect(minfrom:intlen:maxto)[1:nbint]
      tab[!,to]       = tab[!,from] .+ intlen
      tab[!,bh]      .= grp[1,bh]
      tab[!,:LENGTH] .= intlen
      zone != nothing && (tab[!,zone] .= grp[1,zone])

      # get composited intervals for :equalcomp compositing mode
    elseif mode == :equalcomp
      div   = len/interval
      nbint = floor(Int,div)
      last  = (len-nbint*interval)
      last >= mincomp && (nbint += 1)
      last <  mincomp && (last = interval)

      minfrom = minimum(grp[!,:FROM])
      maxto   = maximum(grp[!,:TO])

      tab[!,from]    = collect(minfrom:interval:maxto)[1:nbint]
      tab[!,to]      = tab[!,from] .+ interval
      tab[end,to]   -= (interval-last)
      tab[!,bh]     .= grp[1,bh]
      tab[!,:LENGTH] = tab[!,to] - tab[!,from]
      zone != nothing && (tab[!,zone] .= grp[1,zone])
    end

    # initialize numeric columns that will be composited
    for col in numcols
      tab[!,col] .= -9999.9999
    end
    allowmissing!(tab, numcols)

    # averaging numeric values for each composited interval
    wcols = union(Symbol.([from,to]), numcols)
    for i in 1:size(tab,1)
      f, t = tab[i,from], tab[i,to]
      vals = grp[(grp[!,to] .> f) .& (grp[!,from] .< t), wcols]
      size(vals,1) == 0 && (tab[i,col] = missing)
      size(vals,1) == 0 && continue
      vals[1,from] = f
      vals[end,to] = t
      leng = vals[:,to]-vals[:,from]
      for col in numcols
        ivalid = findall(!ismissing,vals[!,col])
        n = length(ivalid)
        wgt = n >= 1 ? weights(leng[ivalid]) : missing
        n == 0 && (tab[i,col] = missing)
        n == 1 && (tab[i,col] = vals[1,col])
        n >  1 && (tab[i,col] = mean(vals[ivalid,col], wgt))
      end
    end

    # add composited intervals to the output comps table
    comps = vcat(comps, tab, cols=:union)
  end

  # add coordinates to the composites and return a drill hole object
  fillxyz!(comps, dhf.trace, pars)
  DrillHole(comps, dhf.trace, pars)
end
