# Base function to handle retries
## Redundant

function _handle_http_request(max_retries, request_fn)
  for attempt in 1:max_retries
      try
          response = request_fn()
          result = String(response.body)
          result_dict = JSON.Parser.parse(result)
          return result_dict
      catch e
          println("Error: $e")
          if attempt == max_retries
              rethrow(e)
          end
          println("Attempt $attempt failed, retrying...")
          continue
      end
  end
end

# Function for requests without a body
function safe_request(method::String, url::String, headers; max_retries=5)
  request_fn = () -> HTTP.request(method, url, headers)
  return _handle_http_request(max_retries, request_fn)
end

# Function for requests with a body
function safe_request(method::String, url::String, headers, body; max_retries=5)
  request_fn = () -> HTTP.request(method, url, headers, body)
  return _handle_http_request(max_retries, request_fn)
end

