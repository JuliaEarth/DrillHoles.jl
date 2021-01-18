
function validations(c::Collar, s::Survey, intervals::Intervals)
    # get initial info
    cfields = [c.holeid,c.x,c.y,c.z]
    sfields = [s.holeid,s.at,s.azm,s.dip]
    c.enddepth != nothing && push!(cfields,c.enddepth)
    it = intervals isa Interval ? [intervals] : intervals

    # read files
    dfc = c.file isa String ? CSV.read(c.file, DataFrame, select=cfields) : select(c.file,cfields)
    dfs = s.file isa String ? CSV.read(s.file, DataFrame, select=sfields) : select(s.file,sfields)
    dfi = []
    for f in it
        ffields = [f.holeid,f.from,f.to]
        d = f.file isa String ? CSV.read(f.file, DataFrame, select=ffields) : select(f.file,ffields)
        push!(dfi,d)
    end

    # output warning table
    out = DataFrame(TYPE = String[], FILE = String[], DESCRIPTION = String[])

    ## ERRORS
    # check for inappropriate nans
    nanc = [missing isa dtype for dtype in eltype.(eachcol(dfc))]
    nans = [missing isa dtype for dtype in eltype.(eachcol(dfs))]
    nani = [[missing isa dtype for dtype in eltype.(eachcol(df))] for df in dfi]
    # check for inappropriate duplicates
    dupc = findall(nonunique(dfc,[c.holeid]))
    dups = findall(nonunique(dfs,[s.holeid,s.at]))
    # check for typerrors; numeric: coords, enddepth, at, azm, dip from, to
    typc = [Number <: x for x in eltype.(eachcol(dfc))[2:end]]
    typs = [Number <: x for x in eltype.(eachcol(dfs))[2:end]]
    typi = [[Number <: x for x in eltype.(eachcol(df))[2:end]] for df in dfi]
    # check for overlaps
    ovlp = [overlaps(dfi[x],it[x]) for x in 1:length(it)]

    # error descriptions
    outnan(df,nan) = "Missing values in the column(s) $(names(df)[nan])"
    outdup(rows)   = replace("Duplicate values in the row(s) $rows","Any"=>"")
    outtyp(df,typ) = "Non-numeric values in the column(s) $(names(df)[2:end][typ])"
    outovl(rows)   = replace("Overlaps in the row(s) $rows","Any"=>"")
    fname(x)       = x isa String ? Base.Filesystem.basename(x) : @varname(x)

    # check for errors and add it to output table if it exists
    sum(nanc)>0    && push!(out,("Error",fname(c.file),outnan(dfc,nanc)))
    sum(nans)>0    && push!(out,("Error",fname(s.file),outnan(dfs,nans)))
    length(dupc)>0 && push!(out,("Error",fname(c.file),outdup(dupc)))
    length(dups)>0 && push!(out,("Error",fname(s.file),outdup(dups)))
    sum(typc)>0    && push!(out,("Error",fname(c.file),outtyp(dfc,typc)))
    sum(typs)>0    && push!(out,("Error",fname(s.file),outtyp(dfs,typs)))
    for x in 1:length(it)
      sum(nani[x])>0  && push!(out,("Error",fname(it[x].file),outnan(dfi[x],nani[x])))
      sum(typi[x])>0  && push!(out,("Error",fname(it[x].file),outtyp(dfi[x],typi[x])))
      sum(typi[x])==0 && length(ovlp[x])>0 && push!(out,("Error",fname(it[x].file),outovl(ovlp[x])))
    end

    # if some error exists, stop validations and return the errors
    size(out,1)>0 && (return sort!(out,[:TYPE,:DESCRIPTION,:FILE]))

    ## WARNINGS

    # check enddepth
    # check duplicate names and inform (maybe also if there is a preexisting x y z length)
    # bhid do not exist in collar table
    # survey do not exist
    # survey do not exist at zero
    # survey duplicated (same props)
    # survey single value
    # survey vector before and after too different
    # intervals list of absent collars
    # list of numeric interval values; if not, check for alpha values in table
    # warn if coordinate == -9999.9999 during fillxyz!
    # table columns: warn repeated names

    sort!(out,[:TYPE,:DESCRIPTION,:FILE])
end

# check for overlaps
function overlaps(df,pars)
    bh, f, t, ix = pars.holeid, pars.from, pars.to, :_IDX_
    n = size(df,1)
    df[!,ix] = collect(1:n)
    sort!(df,[bh,f,t])

    ovlps = []
    for i in 1:size(df,1)
        df[i,f] >= df[i,t] && push!(ovlps,df[i,ix])
        i==1 && continue
        df[i,bh] != df[i-1,bh] && continue
        df[i,f] < df[i-1,t] && append!(ovlps,[df[i-1,ix],df[i,ix]])
    end
    ovlps
end

"""
    exportwarns(dh::DrillHole, outname="errors")

Export errors and warnings identified during drill hole desurvey of `dh`
to the file `outname`.csv.
"""
exportwarns(dh::DrillHole, outname::String="errors") = CSV.write("$outname.csv", dh.warns)
