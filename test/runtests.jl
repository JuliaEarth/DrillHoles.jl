using DrillHoles
using DataFrames
using Unitful
using Meshes
using Test

@testset "DrillHoles.jl" begin
  collar = Collar(DataFrame(HOLEID=1:2, X=1:2, Y=1:2, Z=1:2))
  survey = Survey(DataFrame(HOLEID=[1, 1, 2, 2], AT=[0, 5, 0, 5], AZM=[0, 1, 20, 21], DIP=[89, 88, 77, 76]))
  assays = Interval(DataFrame(HOLEID=[1, 1, 2], FROM=[1, 3.5, 0], TO=[3.5, 8, 7], A=[1, 2, 3]))
  lithos = Interval(DataFrame(HOLEID=[1, 2, 2], FROM=[0, 0, 4.4], TO=[8, 4.4, 8], L=["A", "B", "C"]))

  dh = desurvey(collar, survey, [assays, lithos], geom=:none)
  @test dh.HOLEID == [1, 1, 1, 2, 2, 2]
  @test dh.FROM ≈ [0.0, 1.0, 3.5, 0.0, 4.4, 7.0] * u"m"
  @test dh.TO ≈ [1.0, 3.5, 8.0, 4.4, 7.0, 8.0] * u"m"
  @test dh.AT ≈ [0.5, 2.25, 5.75, 2.2, 5.7, 7.5] * u"m"
  @test dh.AZM ≈ [0.1, 0.45, 1.15, 20.44, 21.14, 21.5] * u"°"
  @test dh.DIP ≈ [88.9, 88.55, 87.85, 76.56, 75.86, 75.5] * u"°"
  @test isapprox(
    dh.X,
    [
      1.000152273918042,
      1.0006852326311886,
      1.001751150057482,
      2.180003148116409,
      2.466371792847059,
      2.6136470958513938
    ] * u"m",
    atol=1e-5u"m"
  )
  @test isapprox(
    dh.Y,
    [
      1.0130869793585429,
      1.058891407113443,
      1.1505002626232426,
      2.4809751054874134,
      3.2461627733082983,
      3.6396878596161817
    ] * u"m",
    atol=1e-5u"m"
  )
  @test isapprox(
    dh.Z,
    [
      0.5001776737812189,
      -1.2492004679845148,
      -4.747956751515982,
      -0.1391896286156471,
      -3.5424458559587215,
      -5.292691915735159
    ] * u"m",
    atol=1e-5u"m"
  )
  @test isequal(dh.A, [missing, 1, 2, 3, 3, missing])
  @test isequal(dh.L, ["A", "A", "A", "B", "C", "C"])

  # changing step method only changes coordinates X, Y, Z
  dh2 = desurvey(collar, survey, [assays, lithos], step=:tan, geom=:none)
  @test isequal(dh[!, Not([:X, :Y, :Z])], dh2[!, Not([:X, :Y, :Z])])
  @test isapprox(dh2.X, [1.0, 1.0, 1.0, 2.169263142065488, 2.4385454135333093, 2.5770334388596177] * u"m", atol=1e-5u"m")
  @test isapprox(
    dh2.Y,
    [
      1.0087262032186417,
      1.039267914483888,
      1.10035133701438,
      2.4650466607708674,
      3.204893621088157,
      3.5853863435370488
    ] * u"m",
    atol=1e-5u"m"
  )
  @test isapprox(
    dh2.Z,
    [
      0.5000761524218044,
      -1.2496573141018803,
      -4.74912424714925,
      -0.1436141425275177,
      -3.553909369275841,
      -5.307775485889264
    ] * u"m",
    atol=1e-5u"m"
  )

  # point geometries by default
  dh3 = desurvey(collar, survey, [assays, lithos])
  @test eltype(dh3.geometry) <: Point

  # guess column names
  collar = Collar(DataFrame(holeid=1:2, XCOLLAR=1:2, Y=1:2, z=1:2))
  @test collar.holeid == :holeid
  @test collar.x == :XCOLLAR
  @test collar.y == :Y
  @test collar.z == :z
  survey = Survey(DataFrame(HOLEID=[1, 1, 2, 2], at=[0, 5, 0, 5], BRG=[0, 1, 20, 21], DIP=[89, 88, 77, 76]))
  @test survey.holeid == :HOLEID
  @test survey.at == :at
  @test survey.azm == :BRG
  @test survey.dip == :DIP
  assays = Interval(DataFrame(holeid=[1, 1, 2], FROM=[1, 3.5, 0], to=[3.5, 8, 7], A=[1, 2, 3]))
  @test assays.holeid == :holeid
  @test assays.from == :FROM
  @test assays.to == :to

  # result has standard column names
  dh = desurvey(collar, survey, [assays], geom=:none)
  @test propertynames(dh) == [:HOLEID, :FROM, :TO, :AT, :AZM, :DIP, :X, :Y, :Z, :A]

  # custom column names
  cdf = DataFrame(HoleId=1:2, XCollar=1:2, YCollar=1:2, ZCollar=1:2)
  collar = Collar(cdf, holeid=:HoleId, x="XCollar", y=:YCollar, z="ZCollar")
  @test collar.holeid == :HoleId
  @test collar.x == :XCollar
  @test collar.y == :YCollar
  @test collar.z == :ZCollar
  sdf = DataFrame(HoleId=[1, 1, 2, 2], At=[0, 5, 0, 5], Azimuth=[0, 1, 20, 21], Dip=[89, 88, 77, 76])
  survey = Survey(sdf, holeid=:HoleId, at="At", azm=:Azimuth, dip="Dip")
  @test survey.holeid == :HoleId
  @test survey.at == :At
  @test survey.azm == :Azimuth
  @test survey.dip == :Dip
  idf = DataFrame(HoleId=[1, 1, 2], From=[1, 3.5, 0], To=[3.5, 8, 7])
  assays = Interval(idf, holeid=:HoleId, from="From", to=:To)
  @test assays.holeid == :HoleId
  @test assays.from == :From
  @test assays.to == :To

  # Tables.jl interface
  collar = Collar(DataFrame(holeid=1:2, XCOLLAR=1:2, Y=1:2, z=1:2, w=1:2))
  @test Tables.istable(collar)
  @test Tables.rowaccess(collar) == true
  @test Tables.columnaccess(collar) == true
  @test Tables.columnnames(collar) == [:holeid, :XCOLLAR, :Y, :z]
  result = DataFrame(holeid=1:2, XCOLLAR=1:2, Y=1:2, z=1:2)
  @test DataFrame(Tables.rows(collar)) == result
  @test DataFrame(Tables.columns(collar)) == result
  @test DataFrame(collar) == result

  survey =
    Survey(DataFrame(HOLEID=[1, 1, 2, 2], at=[0, 5, 0, 5], BRG=[0, 1, 20, 21], DIP=[89, 88, 77, 76], BAR=[1, 2, 3, 4]))
  @test Tables.istable(survey)
  @test Tables.rowaccess(survey) == true
  @test Tables.columnaccess(survey) == true
  @test Tables.columnnames(survey) == [:HOLEID, :at, :BRG, :DIP]
  result = DataFrame(HOLEID=[1, 1, 2, 2], at=[0, 5, 0, 5], BRG=[0, 1, 20, 21], DIP=[89, 88, 77, 76])
  @test DataFrame(Tables.rows(survey)) == result
  @test DataFrame(Tables.columns(survey)) == result
  @test DataFrame(survey) == result

  assays = Interval(DataFrame(foo=[1, 2, 3], holeid=[1, 1, 2], FROM=[1, 3.5, 0], to=[3.5, 8, 7], A=[1, 2, 3]))
  @test Tables.istable(assays)
  @test Tables.rowaccess(assays) == true
  @test Tables.columnaccess(assays) == true
  @test Tables.columnnames(assays) == [:holeid, :FROM, :to, :foo, :A]
  result = DataFrame(holeid=[1, 1, 2], FROM=[1, 3.5, 0], to=[3.5, 8, 7], foo=[1, 2, 3], A=[1, 2, 3])
  @test DataFrame(Tables.rows(assays)) == result
  @test DataFrame(Tables.columns(assays)) == result
  @test DataFrame(assays) == result
end
