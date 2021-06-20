using DrillHoles
using DataFrames
using Test

@testset "DrillHoles.jl" begin
  @testset "desurvey" begin
    collar = Collar(table=DataFrame(HOLEID=1:2, X=1:2, Y=1:2, Z=1:2))
    survey = Survey(table=DataFrame(HOLEID=[1,1,2,2], AT=[0,5,0,5], AZM=[0,1,20,21], DIP=[89,88,77,76]))
    assays = Interval(table=DataFrame(HOLEID=[1,1,2], FROM=[1,3.5,0], TO=[3.5,8,7], A=[1,2,3]))
    lithos = Interval(table=DataFrame(HOLEID=[1,2,2], FROM=[0,0,4.4], TO=[8,4.4,8], L=["A","B","C"]))

    desurvey(collar, survey, [assays, lithos], method = :arc, convention = :negative)
  end
end
