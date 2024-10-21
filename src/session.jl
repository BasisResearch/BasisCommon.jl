module Session

export process_code, process_code_with_module, SessionState, save_state, load_state

using Serialization
using Spec

using ..BasisCommon: tee_capture

struct SessionState
    variables::Dict{Symbol, Any}
    definitions::Dict{Symbol, Expr}
end
@post SessionState(variables::Dict{Symbol, Any}, definitions::Dict{Symbol, Expr}) = __ret__.variables == variables && __ret__.definitions == definitions "SessionState must store the provided variables and definitions"

empty_sessionstate() = SessionState(Dict{Symbol, Any}(), Dict{Symbol, Expr}())

parse_code(code::String) = Meta.parseall(code)
@pre parse_code(code::String) = length(code) > 0 "code must be non-empty"
@post parse_code(code::String) = isa(__ret__, Expr) "return must be a valid Julia expression"

transform_to_block(code::String) = "begin\n$code\nend"
@pre transform_to_block(code::String) = length(code) > 0 "code must be non-empty"
@post transform_to_block(code::String) = startswith(__ret__, "begin") && endswith(__ret__, "end") "result must be wrapped in begin and end"

function validate_expression(expr::Expr)
    # if expr.head != :block
    #     error("Only block expressions are allowed, but you have a $(expr.head) expression")
    if occursin(r"include\(", string(expr))
        error("Use of include is not allowed")
    elseif occursin(r"eval\(", string(expr))
        error("Use of eval is not allowed")
    end
end
@post validate_expression(expr::Expr) = __ret__ === nothing "validation should pass without returning any value"

function store_variable!(state::SessionState, name::Symbol, value::Any)
    state.variables[name] = value
end
@post store_variable!(state::SessionState, name::Symbol, value::Any) = state.variables[name] == value "variable must be stored correctly"

retrieve_variable(state::SessionState, name::Symbol) = state.variables[name]

define_new_definition!(state::SessionState, name::Symbol, expr::Expr) = state.definitions[name] = expr
@post define_new_definition!(state::SessionState, name::Symbol, expr::Expr) = state.definitions[name] == expr "definition must be stored correctly"

"""
    apply_session_state(mod::Module, state::SessionState)

Apply the session state to the module, recreating variables, functions, and types.

# Arguments
- `mod::Module`: A valid Julia module.
- `state::SessionState`: The current session state.

# Preconditions
- `mod` is a valid Julia module.
- `state` is a valid `SessionState`.

# Postconditions
- The module's state reflects the session state.
"""
function apply_session_state(mod::Module, state::SessionState)
    for (name, value) in state.variables
        Core.eval(mod, :(const $name = $value))
    end
    for (name, expr) in state.definitions
        Core.eval(mod, expr)
    end
end

@post apply_session_state(mod::Module, state::SessionState) = all((isdefined(mod, name) for name in keys(state.variables))) "all variables in the state must be defined in the module"

function result_to_string(result::Any)
    return string(result)
end

"""
    process_code_with_module(code::String, state::SessionState, mod::Module) -> (Any, SessionState)

Process and evaluate a code snippet within the given module, updating the session state.

# Arguments
- `code::String`: The code snippet to be processed and evaluated.
- `state::SessionState`: The current session state.
- `mod::Module`: The module to evaluate the code within.

# Example
```julia
state = SessionState(Dict(), Dict())
mod = Module(:SessionModule)
code = \"\"\"
function add(a, b)
    a + b
end
x = add(2, 3)
\"\"\"
result, updated_state = process_code_with_module(code, state, mod)
println(result)  # Output: 5
```
"""
function process_code_with_module(code::String, state::SessionState, mod::Module; filename="none")
    # transformed_code = transform_to_block(code)
    # transformed_code = code
    # expr = parse_code(transformed_code)
    expr = Meta.parseall(code; filename=filename)
    validate_expression(expr)
    apply_session_state(mod, state)
    result = Core.eval(mod, expr)
    
    # for stmt in expr.args
    #     if stmt isa Expr && stmt.head == :(=)
    #         var_name = stmt.args[1]
    #         var_value = Core.eval(mod, var_name)
    #         store_variable!(state, var_name, var_value)
    #     elseif stmt isa Expr && (stmt.head == :function || stmt.head == :struct)
    #         func_name = stmt.head == :function ? stmt.args[1].args[1] : stmt.args[1]
    #         define_new_definition!(state, func_name, stmt)
    #     end
    # end
    
    return result, state
end

"""
    process_code_with_module_tee(code::AbstractString, state::SessionState, mod::Module)

Process and evaluate a code snippet within the∏π given module, returning the result and the
updated session state, and the stdout captured during execution.
"""
function process_code_with_module_tee(code::AbstractString, state::SessionState, mod::Module; filename="none")
    f() = Session.process_code_with_module(code, state, mod; filename=filename)
    tee_capture(f)
end

@pre process_code_with_module(code::String, state::SessionState, mod::Module) = length(code) > 0 "code must be non-empty"
@post process_code_with_module(code::String, state::SessionState, mod::Module) = isa(__ret__, Tuple) && length(__ret__) == 2 && isa(__ret__[2], SessionState) "must return a tuple with an evaluation result and an updated SessionState"

"""
    process_code(code::String, state::SessionState) -> (Any, SessionState)

Process and evaluate a code snippet, creating a new module and updating the session state.

# Arguments
- `code::String`: The code snippet to be processed and evaluated.
- `state::SessionState`: The current session state.

# Example
```julia
state = SessionState(Dict(), Dict())
code = \"\"\"
function add(a, b)
    a + b
end
x = add(2, 3)
\"\"\"
result, updated_state = process_code(code, state)
println(result)  # Output: 5
```
"""
function process_code(code::String, state::SessionState)
    mod = Module(:SessionModule)
    return process_code_with_module(code, state, mod)
end

@pre process_code(code::String, state::SessionState) = length(code) > 0 "code must be non-empty"
@post process_code(code::String, state::SessionState) = isa(__ret__, Tuple) && length(__ret__) == 2 && isa(__ret__[2], SessionState) "must return a tuple with an evaluation result and an updated SessionState"

process_code(code::String) = process_code(code, empty_sessionstate())
process_code_with_module(code::String, m::Module) = process_code_with_module(code, empty_sessionstate(), m)


"""
    save_state(state::SessionState, filename::String)

Serialize and save the session state to a file.

# Arguments
- `state::SessionState`: The current session state.
- `filename::String`: The file path to save the session state.

# Preconditions
- `state` is a valid `SessionState`.
- `filename` is a valid string representing the file path.

# Postconditions
- The session state is saved to the specified file.
"""
function save_state(state::SessionState, filename::String)
    open(filename, "w") do io
        serialize(io, state)
    end
end

@pre save_state(state::SessionState, filename::String) = isa(state, SessionState) && isa(filename, String) "state must be a SessionState and filename must be a String"
@post save_state(state::SessionState, filename::String) = true "session state must be saved without error"

"""
    load_state(filename::String) -> SessionState

Deserialize and load the session state from a file.

# Arguments
- `filename::String`: The file path to load the session state from.

# Preconditions
- `filename` is a valid string representing the file path.

# Returns
- The loaded `SessionState`.

# Postconditions
- Returns a valid `SessionState` object.
"""
function load_state(filename::String)
    open(filename, "r") do io
        return deserialize(io)
    end
end

@pre load_state(filename::String) = isa(filename, String) "filename must be a String"
@post load_state(filename::String) = isa(__ret__, SessionState) "must return a valid SessionState object"

end
