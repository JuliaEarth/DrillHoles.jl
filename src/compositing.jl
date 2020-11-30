
"""
nan = zero or absent
gaps = 0
mincomp
interval
maxcomp = 1.5*interval; equal to interval
"""

function composite(dhf::DrillHole; interval::Number=1.0,
  zone=nothing, gap=0.001, mincomp=0.5, maxcomp="interval")

  dh = dhf.table
  codes = dhf.codes
  bh, from, to = codes.holeid, codes.from, codes.to

  # get groups to composite
  shift = collect(2:size(dh,1))
  push!(shift,1) # check if works for every case

  chk1 = abs.(dh[shift,to] .- dh[!,from]) .> gap # gap
  chk2 = dh[shift,bh] .!= dh[!,bh] # hole name
  chk3 = zone == nothing ? nothing : (dh[shift,zone] .!= dh[!,zone]) # zone check

  breaks = zone == nothing ? (chk1 .| chk2) : (chk1 .| chk2 .| chk3)
  println(chk1[1:25])
  println(chk2[1:25])
  println(chk3)
  println(breaks[1:25])

  gps = []; c = 1
  for i in 1:size(dh,1)
    breaks[i] && i > 1 && (c += 1)
    push!(gps,c)
  end

  chk = select(dh,[bh,from,to])
  chk[!,"GP"] = gps
  CSV.write("test_groups.csv",chk)

  """
  DrillHole(dhf.trace,comps,codes)
  """
end
