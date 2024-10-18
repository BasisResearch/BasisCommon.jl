## IO Utilities
## ============

export tee_capture

"""
    tee_capture(f)

Evaluates `f()` and captures the output that would have been printed to the console.
This is useful when you want to capture the output of a function that prints to the console.
It also prints the output to the console as it is captured.
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
function tee_capture(func)
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

    result = nothing
    captured_output = ""

    try
        result = func()
    catch e
        @error "Error in captured function" exception=(e, catch_backtrace())
        rethrow(e)
    finally
        redirect_stdout(old_stdout)
        close(wr)
        wait(tee_task)
        captured_output = String(take!(output_buffer))
    end

    return (result = result, stdout = captured_output)
end