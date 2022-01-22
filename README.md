# DrillHoles

[![Build Status][build-img]][build-url] [![Coverage][codecov-img]][codecov-url]

Functions to desurvey and composite drill hole tables from the
mining industry.

## Installation

Get the latest stable release with Julia's package manager:

```julia
] add DrillHoles
```

## Usage

### 1. Desurveying

Given a *collar table*, a *survey table* and at least one *interval
table* (such as assay and lithology), the function `desurvey` can
be used for desurveying. Examples of these tables are shown bellow:

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

The `desurvey` function returns a `DataFrame` with standardized
columns. It supports different dip angle conventions from open
pit and underground mining as well as different stepping methods.
Please check the docstring for more details.

```julia
df = desurvey(collar, survey, [assay, litho])
```

### 2. Compositing

The result of the `desurvey` function can be passed to the
`composite` function for compositing the intervals to a given
length. Please check the docstrings for available methods:

```julia
# request intervals of length 10.0
dc = composite(df, 10.0)
```

### 3. Georeferencing

The `DataFrame` objects produced by both `desurvey` and `composite`
can be georeferenced and used as input for geostatistical modeling
with [GeoStats.jl](https://github.com/JuliaEarth/GeoStats.jl):

```julia
using GeoStats

# georeference table with coordinates
georef(dc, (:X, :Y, :Z))
```

[build-img]: https://img.shields.io/github/workflow/status/JuliaEarth/DrillHoles.jl/CI?style=flat-square
[build-url]: https://github.com/JuliaEarth/DrillHoles.jl/actions

[codecov-img]: https://codecov.io/gh/JuliaEarth/DrillHoles.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaEarth/DrillHoles.jl
