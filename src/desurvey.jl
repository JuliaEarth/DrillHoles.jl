
#abstract type AbstractDrillHole end

Base.@kwdef struct Collar
  file::String
  holeid::Union{String,Symbol} = :HOLEID
  x::Union{String,Symbol} = :X
  y::Union{String,Symbol} = :Y
  z::Union{String,Symbol} = :Z
  enddepth::Union{String,Symbol} = nothing
end

Base.@kwdef struct Survey
  file::String
  holeid::Union{String,Symbol} = :HOLEID
  at::Union{String,Symbol} = :AT
  azm::Union{String,Symbol} = :AZM
  dip::Union{String,Symbol} = :DIP
  invertdip::Union{String,Symbol} = false
end

Base.@kwdef struct IntervalTable
  file::String
  holeid::Union{String,Symbol} = :HOLEID
  from::Union{String,Symbol} = :FROM
  to::Union{String,Symbol} = :TO
end

Intervals = Union{IntervalTable,AbstractArray{IntervalTable}}

struct DrillHole
  collar::Collar # georef?
  survey::Survey
  intervals::Intervals

  trace::PointSet # georef
  table::IntervalTable # georef
end


function drillhole(collar::Collar,survey::Survey,intervals::Intervals)

  trace = trace(collar, survey)
  table = mergetables(trace, intervals)

  DrillHole(collar,survey,intervals,trace,table)
end


function trace(collar, survey)
  # HOLEID,X,Y,Z,AT,AZM,DIP,...
end
