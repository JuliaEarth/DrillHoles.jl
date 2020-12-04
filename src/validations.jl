"""

## warning (sometimes internally resolved)
# check enddepth
# bhid do not exist in collar table
# survey do not exist
# survey do not exist at zero
# survey duplicated (same props)
# survey single value
# survey vector before and after too different
# intervals list of absent collars
# list of numeric interval values; if not, check for alpha values in table

"""

function validations(c::Collar, s::Survey, intervals::Intervals)
    it = intervals isa IntervalTable ? [intervals] : intervals
    cfields = [c.holeid,c.x,c.y,c.z]
    sfields = [s.holeid,s.at,s.azm,s.dip]
    c.enddepth != nothing && push!(cfields,c.enddepth)

    dfc = c.file isa String ? CSV.read(c.file, DataFrame, select=cfields) : select(c.file,cfields)
    dfs = s.file isa String ? CSV.read(s.file, DataFrame, select=sfields) : select(s.file,sfields)
    dfi = []
    for f in it
        ffields = [f.holeid,f.from,f.to]
        d = f.file isa String ? CSV.read(f.file, DataFrame, select=ffields) : select(f.file,ffields)
        push!(dfi,d)
    end

    out = DataFrame(TYPE = String[], FILE = String[], DESCRIPTION = String[])

    ## ERRORS

    # check for inappropriate nans
    nanc = [missing isa dtype for dtype in eltype.(eachcol(dfc))]
    nans = [missing isa dtype for dtype in eltype.(eachcol(dfs))]
    nani = [[missing isa dtype for dtype in eltype.(eachcol(df))] for df in dfi]
    # check for inappropriate duplicates
    dupc = findall(nonunique(dfc,[c.holeid]))
    dups = findall(nonunique(dfs,[s.holeid,s.at]))
    # check for typerrors
    typc = [Number <: x for x in eltype.(eachcol(dfc))[2:end]]
    typs = [Number <: x for x in eltype.(eachcol(dfs))[2:end]]
    typi = [[Number <: x for x in eltype.(eachcol(df))[2:end]] for df in dfi]
    # numeric: coords, enddepth, at, azm, dip from, to
    # check for overlaps
    ovlp = [overlaps(dfi[x],it[x]) for x in 1:length(it)]

    # error descriptions
    outnan(df,nan) = "Missing values in the column(s) $(names(df)[nan])"
    outdup(rows) = "Duplicate values in the row(s) $rows"
    outtyp(df,typ) = "Non-numeric values in the column(s) $(names(df)[2:end][typ])"
    outovl(rows) = "Overlaps in the row(s) $rows"

    # errors out
    sum(nanc)>0 && push!(out,("Error",c.file,outnan(dfc,nanc)))
    sum(nans)>0 && push!(out,("Error",s.file,outnan(dfs,nans)))
    length(dupc)>0 && push!(out,("Error",c.file,outdup(dupc)))
    length(dups)>0 && push!(out,("Error",s.file,outdup(dups)))
    sum(typc)>0 && push!(out,("Error",c.file,outtyp(dfc,typc)))
    sum(typs)>0 && push!(out,("Error",s.file,outtyp(dfs,typs)))
    for x in 1:length(it)
      sum(nani[x])>0 && push!(out,("Error",it[x].file,outnan(dfi[x],nani[x])))
      sum(typi[x])>0 && push!(out,("Error",it[x].file,outtyp(dfi[x],typi[x])))
      sum(typi[x])==0 && length(ovlp[x])>0 && push!(out,("Error",it[x].file,outovl(ovlp[x])))
    end

    size(out,1)>0 && (return sort!(out,[:TYPE,:DESCRIPTION,:FILE]))

    ## WARNINGS
    # do it

    sort!(out,[:TYPE,:DESCRIPTION,:FILE])
end

function overlaps(df,codes)
    bh, f, t, ix = codes.holeid, codes.from, codes.to, :_IDX_
    n = size(df,1)
    df[!,ix] = collect(1:n)
    sort!(df,[bh,f,t])

    ovlps = []
    for i in 1:size(df,1)
        df[i,f] >= df[i,t] && push(ovlps,df[i,ix])
        i==1 && continue
        df[i,bh] != df[i-1,bh] && continue
        df[i,f] < df[i-1,t] && append!(ovlps,[df[i-1,ix],df[i,ix]])
    end

    ovlps
end

function numvalidations(dh)
    # coords bad values
    # interval bad values (or absent): stats and summary
end
