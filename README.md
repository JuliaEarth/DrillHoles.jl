# DrillHoles.jl

[![Build Status][build-img]][build-url] [![Coverage][codecov-img]][codecov-url]

Desurvey and composite drill hole tables from the mining industry.

## Usage

### Desurveying

Given a *collar table*, a *survey table* and at least one *interval
table* (such as assay and lithology), the function `desurvey` can
be used for desurveying and compositing. Examples of these tables
are shown bellow:

![tables](docs/example.png)

- *Collar table*: stores the coordinates (X, Y, Z) of each drill
hole with given ID (HOLEID).
- *Survey table*: stores the arc length (AT) and azimuth (AZM) and
dip (DIP) angles along the drill hole trajectory. Together with the
collar table it fully specifies the trajectory.
- *Interval table*: stores the actual measurements taken on cylinders
of rock defined by an interval of arc lenghts (FROM and TO). Usually,
there are multiple interval tables with different types of measurements.

Assuming that each of these tables was loaded into a
[Tables.jl](https://github.com/JuliaData/Tables.jl) table
(e.g. CSV.File, DataFrame), we can use the following constructors
to automatically detect the columns:

```julia
using DrillHoles
using CSV

collar = Collar(CSV.File("collar.csv"))
survey = Survey(CSV.File("survey.csv"))
assay  = Interval(CSV.File("assay.csv"))
litho  = Interval(CSV.File("litho.csv"))
```

If the columns of the tables follow an exotic naming convention,
users can manually specify the names with keyword arguments:

```julia
# manually specify column with hole ID
Collar(CSV.File("collar.csv"), holeid = :MYID)
```

Please check the documentation of `Collar`, `Survey` and `Interval`
for more details.

The `desurvey` function returns a `DataFrame` with standardized
columns. It supports different dip angle conventions from open
pit and underground mining as well as different stepping methods.
The option `len` can be used for compositing. Please check the
documentation for more details.

```julia
dh = desurvey(collar, survey, [assay, litho])
```

### Georeferencing

The result of `desurvey` can be georeferenced
and used as input for geostatistical modeling
with [GeoStats.jl](https://github.com/JuliaEarth/GeoStats.jl):

```julia
using GeoStats

# georeference table with coordinates
georef(dh, (:X, :Y, :Z))
```

[build-img]: https://img.shields.io/github/workflow/status/JuliaEarth/DrillHoles.jl/CI?style=flat-square
[build-url]: https://github.com/JuliaEarth/DrillHoles.jl/actions

[codecov-img]: https://codecov.io/gh/JuliaEarth/DrillHoles.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaEarth/DrillHoles.jl
