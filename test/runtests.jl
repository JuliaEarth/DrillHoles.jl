using DrillHoles
using DataFrames
using Test

@testset "DrillHoles.jl" begin
  @testset "desurvey" begin
    collar = Collar(DataFrame(HOLEID=1:2, X=1:2, Y=1:2, Z=1:2))
    survey = Survey(DataFrame(HOLEID=[1,1,2,2], AT=[0,5,0,5], AZM=[0,1,20,21], DIP=[89,88,77,76]))
    assays = Interval(DataFrame(HOLEID=[1,1,2], FROM=[1,3.5,0], TO=[3.5,8,7], A=[1,2,3]))
    lithos = Interval(DataFrame(HOLEID=[1,2,2], FROM=[0,0,4.4], TO=[8,4.4,8], L=["A","B","C"]))

    dh = desurvey(collar, survey, [assays, lithos])
    @test dh.SOURCE == [:SURVEY, :INTERVAL, :INTERVAL, :SURVEY, :INTERVAL, :SURVEY, :INTERVAL, :SURVEY, :INTERVAL, :INTERVAL]
    @test dh.HOLEID == [1, 1, 1, 1, 1, 2, 2, 2, 2, 2]
    @test dh.FROM   ≈ [0.0, 0.0, 1.0, 5.0, 3.5, 0.0, 0.0, 5.0, 4.4, 7.0]
    @test dh.TO     ≈ [0.0, 1.0, 3.5, 5.0, 8.0, 0.0, 4.4, 5.0, 7.0, 8.0]
    @test dh.AT     ≈ [0.0, 0.5, 2.25, 5.0, 5.75, 0.0, 2.2, 5.0, 5.7, 7.5]
    @test dh.AZM    ≈ [0.0, 0.1, 0.45, 1.0, 1.15, 20.0, 20.44, 21.0, 21.14, 21.5]
    @test dh.DIP    ≈ [89.0, 88.9, 88.55, 88.0, 87.85, 77.0, 76.56, 76.0, 75.86, 75.5]
    @test isapprox(dh.X, [1.0, 1.00015, 1.00069, 1.00152, 1.00175, 2.0, 2.18, 2.4091, 2.46637, 2.61365], atol=1e-5)
    @test isapprox(dh.Y, [1.0, 1.01309, 1.05889, 1.13087, 1.1505, 2.0, 2.48098, 3.09313, 3.24616, 3.63969], atol=1e-5)
    @test isapprox(dh.Z, [1.0, 0.500178, -1.2492, -3.99822, -4.74796, 2.0, -0.13919, -2.86179, -3.54245, -5.29269], atol=1e-5)
    @test isequal(dh.A, [missing, missing, 1, missing, 2, missing, 3, missing, 3, missing])
    @test isequal(dh.L, [missing, "A", "A", missing, "A", missing, "B", missing, "C", "C"])

    # changing step method only changes coordinates X, Y, Z
    dh2 = desurvey(collar, survey, [assays, lithos], step=:tan)
    @test isequal(dh[!,Not([:X,:Y,:Z])], dh2[!,Not([:X,:Y,:Z])])
    @test isapprox(dh2.X, [1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.16926, 2.38469, 2.43855, 2.57703], atol=1e-5)
    @test isapprox(dh2.Y, [1.0, 1.00873, 1.03927, 1.08726, 1.10035, 2.0, 2.46505, 3.05692, 3.20489, 3.58539], atol=1e-5)
    @test isapprox(dh2.Z, [1.0, 0.500076, -1.24966, -3.99924, -4.74912, 2.0, -0.143614, -2.87185, -3.55391, -5.30778], atol=1e-5)

    # guess column names
    collar = Collar(DataFrame(holeid=1:2, XCOLLAR=1:2, Y=1:2, z=1:2))
    @test collar.holeid == :holeid
    @test collar.x == :XCOLLAR
    @test collar.y == :Y
    @test collar.z == :z
    survey = Survey(DataFrame(HOLEID=[1,1,2,2], at=[0,5,0,5], BRG=[0,1,20,21], DIP=[89,88,77,76]))
    @test survey.holeid == :HOLEID
    @test survey.at == :at
    @test survey.azm == :BRG
    @test survey.dip == :DIP
    assays = Interval(DataFrame(holeid=[1,1,2], FROM=[1,3.5,0], to=[3.5,8,7], A=[1,2,3]))
    @test assays.holeid == :holeid
    @test assays.from == :FROM
    @test assays.to == :to

    # result has standard column names
    dh = desurvey(collar, survey, [assays])
    @test propertynames(dh) == [:SOURCE,:HOLEID,:FROM,:TO,:AT,:AZM,:DIP,:X,:Y,:Z,:A]

    # Tables.jl interface
    collar = Collar(DataFrame(holeid=1:2, XCOLLAR=1:2, Y=1:2, z=1:2, w=1:2))
    @test Tables.istable(collar)
    @test Tables.rowaccess(collar) == true
    @test Tables.columnaccess(collar) == true
    @test Tables.columnnames(collar) == (:holeid, :XCOLLAR, :Y, :z)
    result = DataFrame(holeid=1:2, XCOLLAR=1:2, Y=1:2, z=1:2)
    @test DataFrame(Tables.rows(collar)) == result
    @test DataFrame(Tables.columns(collar)) == result
    @test DataFrame(collar) == result

    survey = Survey(DataFrame(HOLEID=[1,1,2,2], at=[0,5,0,5], BRG=[0,1,20,21], DIP=[89,88,77,76], BAR=[1,2,3,4]))
    @test Tables.istable(survey)
    @test Tables.rowaccess(survey) == true
    @test Tables.columnaccess(survey) == true
    @test Tables.columnnames(survey) == (:HOLEID, :at, :BRG, :DIP)
    result = DataFrame(HOLEID=[1,1,2,2], at=[0,5,0,5], BRG=[0,1,20,21], DIP=[89,88,77,76])
    @test DataFrame(Tables.rows(survey)) == result
    @test DataFrame(Tables.columns(survey)) == result
    @test DataFrame(survey) == result

    assays = Interval(DataFrame(foo=[1,2,3], holeid=[1,1,2], FROM=[1,3.5,0], to=[3.5,8,7], A=[1,2,3]))
    @test Tables.istable(assays)
    @test Tables.rowaccess(assays) == true
    @test Tables.columnaccess(assays) == true
    @test Tables.columnnames(assays) == (:holeid, :FROM, :to, :foo, :A)
    result = DataFrame(holeid=[1,1,2], FROM=[1,3.5,0], to=[3.5,8,7], foo=[1,2,3], A=[1,2,3])
    @test DataFrame(Tables.rows(assays)) == result
    @test DataFrame(Tables.columns(assays)) == result
    @test DataFrame(assays) == result
  end
end
