using DrillHoles
using DataFrames
using Test

@testset "DrillHoles.jl" begin
    # dummy data
    collar = Collar(table=DataFrame(HOLEID=1:2, X=1:2, Y=1:2, Z=1:2))
    survey = Survey(table=DataFrame(HOLEID=[1,1,2,2], AT=[0,5,0,5], AZM=[0,1,20,21], DIP=[89,88,77,76]),
                    method=:mincurv, convention=:negativedownwards)
    assays = Interval(table=DataFrame(HOLEID=[1,1,2], FROM=[1,3.5,0], TO=[3.5,8,7], A=[1,2,3]))
    lithos = Interval(table=DataFrame(HOLEID=[1,2,2], FROM=[0,0,4.4], TO=[8,4.4,8], L=["A","B","C"]))

    # drill hole desurvey tests
    dh  = drillhole(collar, survey, [assays, lithos])
    tab = dh.table

    @test size(tab, 1) == 6
    @test size(tab, 2) == 9
    @test all(isapprox.(tab[!,:HOLEID], [1.0, 1.0, 1.0, 2.0, 2.0, 2.0]))
    @test all(isapprox.(tab[!,:FROM],   [0.0, 1.0, 3.5, 0.0, 4.4, 7.0]))
    @test all(isapprox.(tab[!,:TO],     [1.0, 3.5, 8.0, 4.4, 7.0, 8.0]))
    @test all(isequal.(tab[!,:L],       ["A", "A", "A", "B", "C", "C"]))
    @test all(isequal.(tab[!,:A],       [missing, 1, 2, 3, 3, missing]))
    @test all(round.(tab[!,:X], digits=1) .≈ [1.0, 1.0, 1.0, 2.2, 2.5, 2.6])
    @test all(round.(tab[!,:Y], digits=1) .≈ [1.0, 1.0, 1.2, 2.5, 3.3, 3.7])
    @test all(round.(tab[!,:Z], digits=1) .≈ [1.5, 3.2, 6.7, 4.1, 7.5, 9.3])

    # drill hole :equalcomp compositing tests
    comp1 = composite(dh; zone=:L, mode=:equalcomp)
    tab   = comp1.table

    @test size(tab, 1) == 16
    @test size(tab, 2) == 9
    @test all(isapprox.(tab[!,:HOLEID], [1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2]))
    @test all(isapprox.(tab[!,:FROM],   [0,1,2,3,4,5,6,7,0,1,2,3,4.4,5.4,6.4,7.4]))
    @test all(isapprox.(tab[!,:TO],     [1,2,3,4,5,6,7,8,1,2,3,4,5.4,6.4,7.4,8]))
    @test all(isequal.(tab[!,:L],       ["A","A","A","A","A","A","A","A","B","B","B","B","C","C","C","C"]))
    @test all(round.(tab[!,:X], digits=1) .≈ [1,1,1,1,1,1,1,1,2,2.1,2.2,2.3,2.4,2.5,2.6,2.6])
    @test all(round.(tab[!,:Y], digits=1) .≈ [1,1,1.1,1.1,1.1,1.1,1.2,1.2,2.1,2.3,2.5,2.8,3.1,3.3,3.5,3.7])
    @test all(round.(tab[!,:Z], digits=1) .≈ [1.5,2.5,3.5,4.5,5.5,6.5,7.5,8.5,2.5,3.5,4.4,5.4,6.8,7.7,8.7,9.5])
    @test all(isequal.(round.(tab[!,:A], digits=1), [missing,1,1,1.5,2,2,2,2,3,3,3,3,3,3,3,missing]))

    # drill hole :nodiscard compositing tests
    comp2 = composite(dh; zone=:L, mode=:nodiscard)
    tab   = comp2.table

    @test size(tab, 1) == 16
    @test size(tab, 2) == 9
    @test all(isapprox.(tab[!,:HOLEID], [1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2]))
    @test all(isapprox.(tab[!,:FROM],   [0,1,2,3,4,5,6,7,0,1.1,2.2,3.3,4.4,5.3,6.2,7.1]))
    @test all(isapprox.(tab[!,:TO],     [1,2,3,4,5,6,7,8,1.1,2.2,3.3,4.4,5.3,6.2,7.1,8]))
    @test all(isequal.(tab[!,:L],       ["A","A","A","A","A","A","A","A","B","B","B","B","C","C","C","C"]))
    @test all(round.(tab[!,:X], digits=1) .≈ [1,1,1,1,1,1,1,1,2,2.1,2.2,2.3,2.4,2.5,2.6,2.6])
    @test all(round.(tab[!,:Y], digits=1) .≈ [1,1,1.1,1.1,1.1,1.1,1.2,1.2,2.1,2.4,2.6,2.8,3.1,3.3,3.5,3.7])
    @test all(round.(tab[!,:Z], digits=1) .≈ [1.5,2.5,3.5,4.5,5.5,6.5,7.5,8.5,2.5,3.6,4.7,5.7,6.7,7.6,8.5,9.3])
    @test all(isequal.(round.(tab[!,:A], digits=1), [missing,1,1,1.5,2,2,2,2,3,3,3,3,3,3,3,missing]))

    ##########################################################################

    # tests using different survey method and dip convention
    survey = Survey(table=DataFrame(HOLEID=[1,1,2,2], AT=[0,5,0,5], AZM=[0,1,20,21], DIP=[89,88,77,76]),
                    method=:tangential, convention=:auto)

    # drill hole desurvey tests
    dh  = drillhole(collar, survey, [assays, lithos])
    tab = dh.table

    @test dh.pars.invdip == true
    @test size(tab, 1) == 6
    @test size(tab, 2) == 9
    @test all(isapprox.(tab[!,:HOLEID], [1.0, 1.0, 1.0, 2.0, 2.0, 2.0]))
    @test all(isapprox.(tab[!,:FROM],   [0.0, 1.0, 3.5, 0.0, 4.4, 7.0]))
    @test all(isapprox.(tab[!,:TO],     [1.0, 3.5, 8.0, 4.4, 7.0, 8.0]))
    @test all(isequal.(tab[!,:L],       ["A", "A", "A", "B", "C", "C"]))
    @test all(isequal.(tab[!,:A],       [missing, 1, 2, 3, 3, missing]))
    @test all(round.(tab[!,:X], digits=1) .≈ [1.0, 1.0, 1.0, 2.2, 2.4, 2.6])
    @test all(round.(tab[!,:Y], digits=1) .≈ [1.0, 1.0, 1.1, 2.5, 3.2, 3.6])
    @test all(round.(tab[!,:Z], digits=1) .≈ [0.5,-1.2,-4.7,-0.1,-3.6,-5.3])

    # drill hole :equalcomp compositing tests
    comp1 = composite(dh; zone=:L, mode=:equalcomp)
    tab   = comp1.table

    @test size(tab, 1) == 16
    @test size(tab, 2) == 9
    @test all(isapprox.(tab[!,:HOLEID], [1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2]))
    @test all(isapprox.(tab[!,:FROM],   [0,1,2,3,4,5,6,7,0,1,2,3,4.4,5.4,6.4,7.4]))
    @test all(isapprox.(tab[!,:TO],     [1,2,3,4,5,6,7,8,1,2,3,4,5.4,6.4,7.4,8]))
    @test all(isequal.(tab[!,:L],       ["A","A","A","A","A","A","A","A","B","B","B","B","C","C","C","C"]))
    @test all(round.(tab[!,:X], digits=1) .≈ [1,1,1,1,1,1,1,1,2,2.1,2.2,2.3,2.4,2.5,2.5,2.6])
    @test all(round.(tab[!,:Y], digits=1) .≈ [1,1,1,1.1,1.1,1.1,1.1,1.2,2.1,2.3,2.5,2.7,3,3.3,3.5,3.7])
    @test all(round.(tab[!,:Z], digits=1) .≈ [0.5,-0.5,-1.5,-2.5,-3.5,-4.5,-5.5,-6.5,1.5,0.5,-0.4,-1.4,-2.8,-3.7,-4.7,-5.5])
    @test all(isequal.(round.(tab[!,:A], digits=1), [missing,1,1,1.5,2,2,2,2,3,3,3,3,3,3,3,missing]))

    # drill hole :nodiscard compositing tests
    comp2 = composite(dh; zone=:L, mode=:nodiscard)
    tab   = comp2.table

    @test size(tab, 1) == 16
    @test size(tab, 2) == 9
    @test all(isapprox.(tab[!,:HOLEID], [1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2]))
    @test all(isapprox.(tab[!,:FROM],   [0,1,2,3,4,5,6,7,0,1.1,2.2,3.3,4.4,5.3,6.2,7.1]))
    @test all(isapprox.(tab[!,:TO],     [1,2,3,4,5,6,7,8,1.1,2.2,3.3,4.4,5.3,6.2,7.1,8]))
    @test all(isequal.(tab[!,:L],       ["A","A","A","A","A","A","A","A","B","B","B","B","C","C","C","C"]))
    @test all(round.(tab[!,:X], digits=1) .≈ [1,1,1,1,1,1,1,1,2,2.1,2.2,2.3,2.4,2.4,2.5,2.6])
    @test all(round.(tab[!,:Y], digits=1) .≈ [1,1,1,1.1,1.1,1.1,1.1,1.2,2.1,2.3,2.6,2.8,3,3.2,3.4,3.6])
    @test all(round.(tab[!,:Z], digits=1) .≈ [0.5,-0.5,-1.5,-2.5,-3.5,-4.5,-5.5,-6.5,1.5,0.4,-0.7,-1.8,-2.7,-3.6,-4.5,-5.3])
    @test all(isequal.(round.(tab[!,:A], digits=1), [missing,1,1,1.5,2,2,2,2,3,3,3,3,3,3,3,missing]))
end
