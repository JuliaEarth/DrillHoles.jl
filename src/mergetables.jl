# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

# merge interval tables
function mergetables(intervals)
  # get column names
  interval = first(intervals)
  from, to = interval.from, interval.to

  tabs = [i.table for i in intervals]

  # rename main columns if necessary
  for i in 1:length(tabs)
    t = intervals[i]
    rename!(tabs[i], t.holeid => :HOLEID, t.from => from, t.to => to)
  end

  # merge all tables and get unique from
  hcols = [:HOLEID,from,to]
  out   = vcat(map(x->select(x,hcols),tabs)..., cols=:union)
  out   = unique(vcat(select(out,[:HOLEID,from]),rename(select(out,[:HOLEID,to]), to => from), cols=:union))
  sort!(out, [:HOLEID, from])

  # add unique to and calculate length
  shift = collect(2:size(out,1))
  push!(shift,1) # check if works for every case
  out[!,to]   = out[shift,from]
  out[!,:CHK] = out[shift,:HOLEID]
  out = out[(out[!,to] .> out[!,from]) .& (out[!,:HOLEID] .== out[!,:CHK]),[:HOLEID,from,to]]
  out[!,:LENGTH] = out[!,to] - out[!,from]

  # add all tables values to the merged intervals
  cols = []
  for i in 1:length(tabs)
    push!(cols,setdiff(names(tabs[i]),string.(hcols)))
    tabs[i][!,"_LEN$i"] = tabs[i][!,to]-tabs[i][!,from]
    out = leftjoin(out,select(tabs[i], Not(to)),on=[:HOLEID,from],makeunique=true)
    select!(tabs[i], Not("_LEN$i"))
  end

  # leftjoin might affect order of the output after DataFrames 1.0. sort again
  sort!(out, [:HOLEID, from])

  # loop all merged intervals and columns
  for i in 1:size(out,1)
    for j in 1:length(cols)
      # check how many merged intervals compose one table interval
      ismissing(out[i,"_LEN$j"]) && continue
      adj = Dict(1 => 0, 2 => out[i,"_LEN$j"]-out[i,"LENGTH"])
      adj[2] ≈ 0 && continue
      while adj[2] > 0 && adj[2] ≉  0
        adj[1] += 1
        adj[2] -= out[i+adj[1],"LENGTH"]
      end

      # repeat table interval values to next i2 merged intervals
      i1, i2 = (i+1), (i+adj[1])
      for col in cols[j]
        crow = out[i,col]
        for k in i1:i2
          out[k,col] = crow
        end
      end
    end
  end

  # delete auxiliary length variables
  tcols = [Symbol("_LEN$j") for j in 1:length(tabs)]
  select!(out, Not(tcols))
end
