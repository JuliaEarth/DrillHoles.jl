
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
Base.@kwdef struct Survey
	file::Union{String,AbstractDataFrame}
	holeid::Union{String,Symbol} = :HOLEID
	at::Union{String,Symbol} = :AT
	azm::Union{String,Symbol} = :AZM
	dip::Union{String,Symbol} = :DIP
	invertdip::Bool = false
	method::Symbol = :mincurv
end

Base.show(io::IO, tb::Survey) = print(io, "Survey")
Base.show(io::IO, ::MIME"text/plain", tb::Survey) = print(io, "Survey object")

"""
    IntervalTable(file, holeid=:HOLEID, from=:FROM, to=:TO)

The definition of one drill hole interval table and its main column fields.
`file` can be a `String` filepath or an already loaded `AbstractDataFrame`.
Examples of interval tables are lithological and assay tables.
"""
Base.@kwdef struct IntervalTable
	file::Union{String,AbstractDataFrame}
	holeid::Union{String,Symbol} = :HOLEID
	from::Union{String,Symbol} = :FROM
	to::Union{String,Symbol} = :TO
end

Base.show(io::IO, tb::IntervalTable) = print(io, "IntervalTable")
Base.show(io::IO, ::MIME"text/plain", tb::IntervalTable) = print(io, "IntervalTable object")

Intervals = Union{IntervalTable,AbstractArray{IntervalTable}}

"""
    DrillHole(table, trace, pars, warns)

Drill hole object. `table` stores the desurveyed data. `trace` and `pars` store
parameters for eventual post-processing or later drill hole compositing. `warns`
report possible problems with input files.
"""
struct DrillHole
	table::Union{AbstractDataFrame,Nothing} # georef later to PointSet or something else
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
		println(io,"DrillHole table with $(d[1]) intervals")
		println(io,"- Warnings: $(size(dh.warns,1))")
		println(io,"- Column variables: $cols")
	end
end
