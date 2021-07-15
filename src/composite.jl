# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    composite(dh, length; method=:flexible, domain=nothing)

Composite drillhole samples `dh` produced by [`desurvey`](@ref) to a
given `length` using `method`. Optionally, specify a `domain` variable
to decide whether or not to combine two samples.

## Methods

- `:strict`   - samples have the exact specified `length`
- `:flexible` - samples can have slightly different `length`

## References

* Abzalov, M. 2018. [Applied Mining Geology](https://www.springer.com/gp/book/9783319392639)
"""
function composite(dh, length; method=:flexible, domain=nothing)
  # extract interval table
  interv = filter(row -> row.SOURCE == :INTERVAL, dh)

  # process each drillhole separately
  for hole in groupby(interv, :HOLEID)
    # TODO
  end
end
