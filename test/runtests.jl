using DrillHoles
using DataFrames
using Test

@testset "DrillHoles.jl" begin
  @testset "desurvey" begin
    collar = Collar(DataFrame(HOLEID=1:2, X=1:2, Y=1:2, Z=1:2))
    survey = Survey(DataFrame(HOLEID=[1,1,2,2], AT=[0,5,0,5], AZM=[0,1,20,21], DIP=[89,88,77,76]))
    assays = Interval(DataFrame(HOLEID=[1,1,2], FROM=[1,3.5,0], TO=[3.5,8,7], A=[1,2,3]))
    lithos = Interval(DataFrame(HOLEID=[1,2,2], FROM=[0,0,4.4], TO=[8,4.4,8], L=["A","B","C"]))

    dh = desurvey(survey, collar, [assays, lithos])
    @test dh.HOLEID == [1, 1, 1, 1, 1, 2, 2, 2, 2, 2]
    @test dh.FROM   ≈ [0.0, 0.0, 1.0, 5.0, 3.5, 0.0, 0.0, 5.0, 4.4, 7.0]
    @test dh.TO     ≈ [0.0, 1.0, 3.5, 5.0, 8.0, 0.0, 4.4, 5.0, 7.0, 8.0]
    @test dh.AT     ≈ [0.0, 0.5, 2.25, 5.0, 5.75, 0.0, 2.2, 5.0, 5.7, 7.5]
    @test dh.AZM    ≈ [0.0, 0.1, 0.45, 1.0, 1.15, 20.0, 20.44, 21.0, 21.14, 21.5]
    @test dh.DIP    ≈ [89.0, 88.9, 88.55, 88.0, 87.85, 77.0, 76.56, 76.0, 75.86, 75.5]
    @test isapprox(dh.X, [1.0, 1.00001, 1.00021, 1.00132, 1.00183, 2.0, 2.17392, 2.40893, 2.47011, 2.632], atol=1e-5)
    @test isapprox(dh.Y, [1.0, 1.00916, 1.0481, 1.13087, 1.15802, 2.0, 2.4721, 3.09321, 3.25201, 3.66674], atol=1e-5)
    @test isapprox(dh.Z, [1.0, 0.500084, -1.24948, -3.99822, -4.74773, 2.0, -0.141693, -2.86179, -3.54079, -5.28486], atol=1e-5)
    @test isequal(dh.A, [missing, missing, 1, missing, 2, missing, 3, missing, 3, missing])
    @test isequal(dh.L, [missing, "A", "A", missing, "A", missing, "B", missing, "C", "C"])
  end
end
