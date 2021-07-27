# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    composite(dh, L; method=:flex, domain=nothing)

Composite drillhole samples `dh` produced by [`desurvey`](@ref) to a
given length `L` using `method`. Optionally, specify a `domain` variable
to decide whether or not to combine two samples.

## Methods

- `:cons` - samples have the exact specified `length`
- `:flex` - samples can have slightly different `length`

## References

* Abzalov, M. 2018. [Applied Mining Geology](https://www.springer.com/gp/book/9783319392639)
"""
function composite(drillholes, L; method=:flex, domain=nothing)
  # process each drillhole separately
  for hole in groupby(drillholes, :HOLEID)
    # extract survey and interval tables
    stable = filter(row -> row.SOURCE == :SURVEY, hole)
    itable = filter(row -> row.SOURCE == :INTERVAL, hole)

    # discard columns that will be recomputed
    dh = view(itable, :, Not([:SOURCE,:HOLEID,:AT,:AZM,:DIP,:X,:Y,:Z]))

    # retrieve depth columns
    FROM, TO = dh.FROM, dh.TO

    # number of composite intervals
    N = ceil(Int, (TO[end] - FROM[begin]) / L)

    # split original intervals into sub-intervals
    # that fit perfectly within composite intervals
    j  = 1
    id = Int[]
    sh = similar(dh, 0)
    for i in 1:N-1
      # current interface
      AT = FROM[begin] + i*L

      # copy all intervals before interface
      while TO[j] < AT
        push!(sh, dh[j,:])
        push!(id, i)
        j += 1
      end

      # make sure this is not a gap
      if FROM[j] < AT
        # first sub-interval at interface
        push!(sh, dh[j,:])
        push!(id, i)
        sh.TO[end] = AT

        # second sub-interval at interface
        push!(sh, dh[j,:])
        push!(id, i+1)
        sh.FROM[end] = AT
      end
    end

    # last composite interval (i = N)
    while j < size(dh, 1)
      j += 1
      push!(sh, dh[j,:])
      push!(id, N)
    end

    # composite id and interval lengths
    sh[!,:ID_]  = id
    sh[!,:LEN_] = sh.TO - sh.FROM

    # variables of interest
    allcols = propertynames(sh)
    discard = [:FROM,:TO,:ID_,:LEN_]
    allvars = setdiff(allcols, discard)

    # perform aggregation
    for d in groupby(sh, :ID_)
      for var in allvars
        x = d[!,var]
        l = d[!,:LEN_]
        x̄ = aggregate(x, l)
      end
    end
  end
end

# helper function to aggregate vectors
function aggregate(x, l)
  # scientific type
  T = x |> scitype_union |> nonmissingtype

  # discard missing
  m  = @. !ismissing(x)
  xm = x[m]
  lm = l[m]

  # dipatch on scientific type
  isempty(xm) ? missing : _aggregate(T, xm, lm)
end

_aggregate(::Type{<:Continuous}, x, l) = (x ⋅ l) / sum(l)
_aggregate(::Type{<:Multiclass}, x, l) = x[argmax(l)]
