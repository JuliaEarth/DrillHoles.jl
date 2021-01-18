
"""
    Collar(file, holeid=:HOLEID, x=:X, y=:Y ,z=:Z, enddepth=nothing)

The definition of the drill hole collar table and its main column fields.
`file` can be a `String` filepath or an already loaded `AbstractDataFrame`.
"""
Base.@kwdef struct Collar
	file::Union{String,AbstractDataFrame}
	holeid::Union{String,Symbol} = :HOLEID
	x::Union{String,Symbol} = :X
	y::Union{String,Symbol} = :Y
	z::Union{String,Symbol} = :Z
	enddepth::Union{String,Symbol,Nothing} = nothing
end

Base.show(io::IO, tb::Collar) = print(io, "Collar")
Base.show(io::IO, ::MIME"text/plain", tb::Collar) = print(io, "Collar object")

"""
    Survey(file, holeid=:HOLEID, at=:AT, azm=:AZM ,dip=:DIP, invertdip=false)

The definition of the drill hole survey table and its main column fields.
`file` can be a `String` filepath or an already loaded `AbstractDataFrame`.
Negative dip points downwards (or upwards if `invertdip`=true). Available methods
for desurvey are `:mincurv` (minimum curvature/spherical arc) and `:tangential`.
"""
struct Survey
	file::Union{String,AbstractDataFrame}
	holeid::Union{String,Symbol}
	at::Union{String,Symbol}
	azm::Union{String,Symbol}
	dip::Union{String,Symbol}
	invertdip::Bool
	method::Symbol

	function Survey(; file, holeid=:HOLEID, at=:AT, azm=:AZM, dip=:DIP,
	  invertdip=false, method=:mincurv)
	  @assert method ∈ [:mincurv, :tangential] "invalid method; choose :mincurv or :tangential"
	  new(file, holeid, at, azm, dip, invertdip, method)
	end
end

Base.show(io::IO, tb::Survey) = print(io, "Survey")
Base.show(io::IO, ::MIME"text/plain", tb::Survey) = print(io, "Survey object")

"""
    Interval(file, holeid=:HOLEID, from=:FROM, to=:TO)

The definition of one drill hole interval table and its main column fields.
`file` can be a `String` filepath or an already loaded `AbstractDataFrame`.
Examples of interval tables are lithological and assay tables.
"""
Base.@kwdef struct Interval
	file::Union{String,AbstractDataFrame}
	holeid::Union{String,Symbol} = :HOLEID
	from::Union{String,Symbol} = :FROM
	to::Union{String,Symbol} = :TO
end

Base.show(io::IO, tb::Interval) = print(io, "Interval")
Base.show(io::IO, ::MIME"text/plain", tb::Interval) = print(io, "Interval object")

Intervals = Union{Interval,AbstractArray{Interval}}

"""
    DrillHole(table, trace, pars, warns)

Drill hole object. `table` stores the desurveyed data. `trace` and `pars` store
parameters for eventual post-processing or later drill hole compositing. `warns`
report possible problems with input files.
"""
struct DrillHole
	table::Union{AbstractDataFrame,Nothing}
	trace::Union{AbstractDataFrame,Nothing}
	pars::NamedTuple
	warns::AbstractDataFrame
end

Base.show(io::IO, dh::DrillHole) = print(io, "DrillHole")

function Base.show(io::IO, ::MIME"text/plain", dh::DrillHole)
	if dh.table == nothing
		printstyled(io,"Error: during drill hole desurveying; check data tables\n", bold=true, color=:red)
		printstyled(io,"\n$(dh.warns)", color=:light_red)
		printstyled(io,"\n\n- check DrillHole.warns for more details", color=:red)
		printstyled(io,"\n- or export to csv: exportwarns(::DrillHole)", color=:red)
	else
		d = size(dh.table)
		w = size(dh.warns,1)
		print(io,"DrillHole with $(d[1]) intervals, $(d[2]) columns and $w warnings")
	end
end

macro varname(arg)
    string(arg)
end
