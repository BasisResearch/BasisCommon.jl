# BasisCommon.jl

[![CI](https://github.com/BasisResearch/BasisCommon/workflows/CI/badge.svg)](https://github.com/BasisResearch/BasisCommon/actions/workflows/ci.yml)

[![CI](https://github.com/<owner>/<repo>/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/<owner>/<repo>/actions/workflows/ci.yml)

BasisCommon is a collection of modules providing essential functionality such as session management, 
HTTP request handling, cost estimation, external variable retrieval, and other utilities 
that can be commonly used across various Julia projects.

## Installation

If not already done, add the package (once it's registered or from a specific repo):

```julia
using Pkg
Pkg.add("BasisCommon")
```

## Usage Example

```julia
using BasisCommon
```

Use Session features, for example:
```julia
session_state = BasisCommon.Session.empty_sessionstate()
```

Or retrieve environment-based variables with the ExoVars module:
```julia
using BasisCommon.ExoVars
with_env_handler() do
    value = get_exo_value("MY_VAR")
    println(value)
end
``