

function mergetables(intervals, codes)
    bh, from, to = codes.holeid, codes.from, codes.to

    tabs = intervals isa IntervalTable ? [intervals] : intervals
    dfs = [CSV.read(f.file, DataFrame) for f in tabs]

    for i in 1:length(dfs)
        t = tabs[i]
        rename!(dfs[i], t.holeid => bh, t.from => from, t.to => to)
    end

    # get all possible intervals
    hcols = [bh,from,to]
    dfx = vcat(map(x->select(x,hcols),dfs)..., cols=:union)
    dfx = unique(vcat(select(dfx,[bh,from]),rename(select(dfx,[bh,to]), to => from), cols=:union))
    sort!(dfx, [bh, from])
    shift = collect(2:size(dfx,1))
    push!(shift,1) # check if works for every case
    dfx[!,to] = dfx[shift,from]
    dfx[!,:CHK] = dfx[shift,bh]
    dfx = dfx[(dfx[!,to] .> dfx[!,from]) .& (dfx[!,bh] .== dfx[!,:CHK]),[bh,from,to]]
    dfx[!,:LENGTH] = dfx[!,to] - dfx[!,from]

    # add table values
    cols = []
    for i in 1:length(dfs)
        push!(cols,setdiff(names(dfs[i]),string.(hcols)))
        dfs[i][!,"_LEN$i"] = dfs[i][!,to]-dfs[i][!,from]
        dfx = leftjoin(dfx,select(dfs[i], Not(to)),on=[bh,from],makeunique=true)
    end

    for i in 1:size(dfx,1)
        for j in 1:length(cols)
            ismissing(dfx[i,"_LEN$j"]) && continue
            adj = Dict(1 => 0, 2 => dfx[i,"_LEN$j"]-dfx[i,"LENGTH"])
            adj[2] == 0 && continue

            while adj[2] > 0
                adj[1] += 1
                adj[2] -= dfx[i+adj[1],"LENGTH"]
            end

            i1, i2 = (i+1), (i+adj[1])

            for col in cols[j]
                crow = dfx[i,col]
                for k in i1:i2
                    dfx[k,col] = crow
                end
            end
        end
    end

    tcols = [Symbol("_LEN$j") for j in 1:length(cols)]
    select!(dfx, Not(tcols))
end
