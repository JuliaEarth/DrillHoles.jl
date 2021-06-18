# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

# merge interval tables
function mergetables(intervals)
  # standardize column names to HOLEID, FROM, TO
  tables = [rename(DataFrame(interval.table),
                   interval.holeid => :HOLEID,
                   interval.from   => :FROM,
                   interval.to     => :TO) for interval in intervals]

  # merge all tables and get unique from
  hcols = [:HOLEID,:FROM,:TO]
  out   = vcat([select(table, hcols) for table in tables]..., cols=:union)
  out   = unique(vcat(select(out,[:HOLEID,:FROM]),rename(select(out,[:HOLEID,:TO]), :TO => :FROM), cols=:union))
  sort!(out, [:HOLEID, :FROM])

  # add unique to and calculate length
  shift = collect(2:size(out,1))
  push!(shift,1) # check if works for every case
  out[!,:TO]  = out[shift,:FROM]
  out[!,:CHK] = out[shift,:HOLEID]
  out = out[(out[!,:TO] .> out[!,:FROM]) .& (out[!,:HOLEID] .== out[!,:CHK]),[:HOLEID,:FROM,:TO]]
  out[!,:LENGTH] = out[!,:TO] - out[!,:FROM]

  # add all tables values to the merged intervals
  cols = []
  for i in 1:length(tables)
    push!(cols,setdiff(names(tables[i]),string.(hcols)))
    tables[i][!,"_LEN$i"] = tables[i][!,:TO]-tables[i][!,:FROM]
    out = leftjoin(out,select(tables[i], Not(:TO)),on=[:HOLEID,:FROM],makeunique=true)
    select!(tables[i], Not("_LEN$i"))
  end

  # leftjoin might affect order of the output after DataFrames 1.0. sort again
  sort!(out, [:HOLEID, :FROM])

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
  tcols = [Symbol("_LEN$j") for j in 1:length(tables)]
  select!(out, Not(tcols))
end
