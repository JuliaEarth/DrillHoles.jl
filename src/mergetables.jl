# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

# merge interval tables
function mergetables(intervals, pars)
  # get column names
  bh, from, to = pars.holeid, pars.from, pars.to

  # read all interval tables
  interv = intervals isa Interval ? [intervals] : intervals
  tabs = [f.file isa String ? CSV.read(f.file, DataFrame) : f.file for f in interv]

  # rename main columns if necessary
  for i in 1:length(tabs)
    t = interv[i]
    rename!(tabs[i], t.holeid => bh, t.from => from, t.to => to)
  end

  # merge all tables and get unique from
  hcols = [bh,from,to]
  out   = vcat(map(x->select(x,hcols),tabs)..., cols=:union)
  out   = unique(vcat(select(out,[bh,from]),rename(select(out,[bh,to]), to => from), cols=:union))
  sort!(out, [bh, from])

  # add unique to and calculate length
  shift = collect(2:size(out,1))
  push!(shift,1) # check if works for every case
  out[!,to]   = out[shift,from]
  out[!,:CHK] = out[shift,bh]
  out = out[(out[!,to] .> out[!,from]) .& (out[!,bh] .== out[!,:CHK]),[bh,from,to]]
  out[!,:LENGTH] = out[!,to] - out[!,from]

  # add all tables values to the merged intervals
  cols = []
  for i in 1:length(tabs)
    push!(cols,setdiff(names(tabs[i]),string.(hcols)))
    tabs[i][!,"_LEN$i"] = tabs[i][!,to]-tabs[i][!,from]
    out = leftjoin(out,select(tabs[i], Not(to)),on=[bh,from],makeunique=true)
    select!(tabs[i], Not("_LEN$i"))
  end

  # leftjoin might affect order of the output after DataFrames 1.0. sort again
  sort!(out, [bh, from])

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
