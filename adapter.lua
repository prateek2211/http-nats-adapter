package.path = './deps/?.lua;' .. package.path
pcall(require, 'luarocks.require')
local uuid   = require('uuid')
local nats = require 'nats'
local http_server = require "http.server"
local http_headers = require "http.headers"

local http_port = 8080
local params = {
    host = '127.0.0.1',
    port = 4222,
}

local client = nats.connect(params)

-- client:enable_trace()
-- client:set_auth('user', 'password')
client:connect()


local function callback(message)
	print("Ack Received", message)
end

local function create_inbox()
    return '_INBOX.' .. uuid()
end


local function publish_message()
	local msg = coroutine.yield()
	local inbox = create_inbox()
    unique_id = client:subscribe(inbox, function(message, reply)
        client:unsubscribe(unique_id)
		callback(message, reply)
    end)

	client:publish("foo", msg, inbox)
	client:wait(1)
end

local function reply(myserver, stream) -- luacheck: ignore 212
	co = coroutine.create(publish_message)
	coroutine.resume(co)
	-- Read in headers
	local req_headers = assert(stream:get_headers())
	local req_method = req_headers:get ":method"

	-- Log request to stdout
	assert(io.stdout:write(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s"\n',
		os.date("%d/%b/%Y:%H:%M:%S %z"),
		req_method or "",
		req_headers:get(":path") or "",
		stream.connection.version,
		req_headers:get("referer") or "-",
		req_headers:get("user-agent") or "-"
	)))

	-- Build response headers
	local res_headers = http_headers.new()
	res_headers:append(":status", "200")
	res_headers:append("content-type", "text/plain")
	-- Send headers to client; end the stream immediately if this was a HEAD request
	assert(stream:write_headers(res_headers, req_method == "HEAD"))
	if req_method ~= "HEAD" then
		-- Send body, ending the stream
		assert(stream:write_chunk("Hello world!\n", true))
    end
    
    local body = stream:get_body_as_string(1)
	coroutine.resume(co, body)
end

local listen = assert(http_server.listen {
	host = "localhost";
	port = http_port;
	onstream = reply;
	onerror = function(myserver, context, op, err, errno)
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end;
})

assert(listen:listen())
do
	local bound_port = select(3, listen:localname())
	assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end

-- Start the main server loop
assert(listen:loop())