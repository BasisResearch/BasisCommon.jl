## IO Utilities
## ============

export tee_capture

const BackTrace =  Vector{Union{Ptr{Nothing}, Base.InterpreterIP}}

"""
    CapturedError{E}

A struct that captures an error and the output that was printed to the console at the time of the error.
"""
struct CapturedError{E <: Exception} <: Exception
    error::E
    stdout::String
    bt::BackTrace
end

function Base.showerror(io::IO, e::CapturedError)
    println(io, "CapturedError: ")
    showerror(io, e.error, e.bt)
    if !isempty(e.stdout)
        println(io, "\nCaptured the following output from stdout before the error occurred:")
        println(io, e.stdout)
    else
        println(io, "\nNo stdout output was captured before the error occurred.")
    end
end

Base.show(io::IO, e::CapturedError) = showerror(io, e)

"""
    reprerror(e::Exception)

Return a string representation of an exception, as shown by `showerror`.

# Examples

```julia
g() = rand() > 0.5 ? error("An error occurred") : 42
function f()
    for i = 1:100
        result = g()
        @show result
    end
end
e = try
    f()
catch e
    e
end
reprerror(e)
```
"""
reprerror(e::Exception) = sprint(showerror, e)

"""
    tee_capture(f)

Evaluates `f()` and captures the output that would have been printed to the console.
This is useful when you want to capture the output of a function that prints to the console.
The captured output is returned as a string, along with the result of `f()`.

# Examples
```julia
function my_program()
    println("Starting my_program...")
    for i in 1:3
        println("Iteration \$i")
        if i % 2 == 0
            println("This is an even iteration.")
        end
    end
    @show sum(1:10)
    println("my_program finished!")
    return 42  # Example return value
end

# Capture and display the output
println("Running my_program with tee_capture:")
result, captured_output = tee_capture(my_program)
println("\\nCaptured output (this should be identical to what we saw above):")
println(captured_output)
println("\\nFunction return value: \$result")
```
"""
function tee_capture(func; capture_on_error = true)
    old_stdout = stdout
    rd, wr = redirect_stdout()
    output_buffer = IOBuffer()
    
    tee_task = @async begin
        try
            while !eof(rd)
                char = read(rd, Char)
                write(old_stdout, char)
                write(output_buffer, char)
            end
        catch e
            @error "Error in tee task" exception=(e, catch_backtrace())
        end
    end

    cleanedup = false
    captured_output = ""

    result = try
        result = func()
    catch e
        @error "Error in captured function" exception=(e, catch_backtrace())
        if capture_on_error
            # Still capture the output
            redirect_stdout(old_stdout)
            close(wr)
            wait(tee_task)
            captured_output = String(take!(output_buffer))
            cleanedup = true
            bt = catch_backtrace()
            throw(CapturedError(e, captured_output, bt))
        else
            rethrow(e)
        end
    finally
        # @show "wrapping up"
        if !cleanedup
            redirect_stdout(old_stdout)
            close(wr)
            wait(tee_task)
            captured_output = String(take!(output_buffer))
        end
    end

    return (result = result, stdout = captured_output)
end