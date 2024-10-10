module ExoVars

using CassetteOverlay

export get_exo_value, EXO, with_env_handler, with_interactive_handler, @env, @interactive

"""
    get_exo_value(key::String)
    EXO[key::String]

Get the value of an external variable.

# Arguments
- `key::String`: The key of the external variable.

# Returns
- The value of the external variable.

# Example
```julia
julia> ENV["MY_VAR"] = "Hello, World!"
"Hello, World!"

    julia> ExoVars.with_env_handler() do
                ExoVars.get_exo_value("MY_VAR")
            end
"Hello, World!"

julia> ExoVars.with_env_handler() do
            ExoVars.EXO["MY_VAR"]
        end
"Hello, World!"
```
"""
function get_exo_value end

# Define EXO as a proxy object
struct EXOProxy end

"""
    EXO

A global object for accessing external variables, similar to `ENV`.
It's an alias for the `get_exo_value` function, allowing dict-like syntax.
"""
const EXO = EXOProxy()

Base.getindex(::EXOProxy, key::String) = get_exo_value(key)

# Define the method tables for the handlers
@MethodTable EnvTable
@MethodTable InteractiveTable

# Define the overlay methods for getting external values
@overlay EnvTable get_exo_value(key::String) = ENV[key]

@overlay InteractiveTable get_exo_value(key::String) = begin
    println("Please enter a value for $key:")
    readline()
end

# Define the overlay pass for executing with a specific handler
const env_pass = @overlaypass EnvTable
const interactive_pass = @overlaypass InteractiveTable

"""
    with_env_handler(f)

Execute the given function `f` using the environment handler for external variables.

This function uses the `ENV` dictionary to retrieve values for external variables.

# Arguments
- `f`: A function to be executed with the environment handler.

# Returns
- The result of executing the function `f`.

# Example
```julia
julia> ENV["MY_VAR"] = "Hello, World!"
"Hello, World!"

julia> ExoVars.with_env_handler() do
            println(ExoVars.get_exo_value("MY_VAR"))
            println(ExoVars.EXO["MY_VAR"])
        end
Hello, World!
Hello, World!
```
"""
function with_env_handler(f)
    env_pass(f)
end

"""
    with_interactive_handler(f)

Execute the given function `f` using the interactive handler for external variables.

This function prompts the user to input values for external variables when they are requested.

# Arguments
- `f`: A function to be executed with the interactive handler.

# Returns
- The result of executing the function `f`.

# Example
   ```julia
   julia> ExoVars.with_interactive_handler() do
              println("The value is: ", ExoVars.get_exo_value("USER_INPUT"))
              println("And again: ", ExoVars.EXO["USER_INPUT"])
          end
   Please enter a value for USER_INPUT:
   42
   The value is: 42
   Please enter a value for USER_INPUT:
   42
   And again: 42
   ```
"""
function with_interactive_handler(f)
    interactive_pass(f)
end

"""
    @env expr

A macro that executes the given expression using the environment handler.

# Arguments
- `expr`: The expression to be executed with the environment handler.

# Returns
- The result of executing the expression with the environment handler.

# Example
```julia
julia> ENV["MY_VAR"] = "Hello, World!"
"Hello, World!"

julia> ExoVars.@env println(ExoVars.EXO["MY_VAR"])
Hello, World!
```
"""
macro env(expr)
    quote
        with_env_handler() do
            $(esc(expr))
        end
    end
end

"""
    @interactive expr

A macro that executes the given expression using the interactive handler.

# Arguments
- `expr`: The expression to be executed with the interactive handler.

# Returns
- The result of executing the expression with the interactive handler.

# Example
```julia
julia> ExoVars.@interactive println("The value is: ", ExoVars.EXO["USER_INPUT"])
Please enter a value for USER_INPUT:
42
The value is: 42
```
"""
macro interactive(expr)
    quote
        with_interactive_handler() do
            $(esc(expr))
        end
    end
end

end # module ExoVars