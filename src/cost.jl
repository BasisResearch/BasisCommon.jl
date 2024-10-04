export estimatecost, trackcosts
using Cassette

Cassette.@context CostContext

Cassette.@context TrackCostsContext

"""
Calculate the cost of computing f(args...).

```julia
using BasisCommon, LMBase
names = [\"John\", \"Mary the 8th\", \"Peter of Tarth\"]
prompts = map(name -> \"Hello, my name is \$name. What is your name?\", names)
f() = [LMBase.OpenAI.call_gpt(prompt) for prompt in prompts]
trackcosts(f)
```
"""
function trackcosts(f, args...)
    ctx = TrackCostsContext(metadata=[])
    # This indirection is because otherwise direct calls to
    # resource consuming fucntions won't register, e.g. estimatecost(call_gpt, prompt)
    callf() = f(args...)  
    Cassette.overdub(ctx, callf)
    return ctx.metadata
end

"""
    `estimatecost(f, args...)`

Estimate the cost of computing `f(args...)`, where `f` is a function or
soem other callable object and args are arguments

## Returns
Vector of costs for each costly procedural call within `f`.

## Example

```julia
using BasisCommon, LMBase
names = [\"John\", \"Mary the 8th\", \"Peter of Tarth\"]
prompts = map(name -> \"Hello, my name is \$name. What is your name?\", names)
f() = [LMBase.OpenAI.call_gpt(prompt) for prompt in prompts]
estimatecost(f)
```
"""
function estimatecost(f, args...)
    ctx = CostContext(metadata=[])
    # This indirection is because otherwise direct calls to
    # resource consuming fucntions won't register, e.g. estimatecost(call_gpt, prompt)
    callf() = f(args...)  
    Cassette.overdub(ctx, callf)
    return ctx.metadata
end