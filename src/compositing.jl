
"""
nan = :zero or skip
gaps = 0
mincomp
interval
aim = :equalcomp or :nodiscard
density weighted?
core recovery?
"""

function composite(dhf::DrillHole; interval::Number=1.0,
  zone=nothing, gap=0.001, mincomp=0.5, aim=:equalcomp)

  dh = copy(dhf.table)
  codes = dhf.codes
  bh, from, to = codes.holeid, codes.from, codes.to

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

    if aim == :nodiscard
      div = len/interval
      if div <= 1 || isinteger(div)
        nbint = ceil(Int,div)
      else
        prenbint = [floor(Int,div), ceil(Int,div)]
        closest = argmin([abs(interval-len/x) for x in prenbint])
        nbint = prenbint[closest]
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

  fillxyz!(comps, dhf.trace, codes)
  DrillHole(dhf.trace,comps,codes)
end
