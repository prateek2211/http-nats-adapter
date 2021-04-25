package.path = './deps/?.lua;' .. package.path
local nats = require 'nats'

local params = {
    host = '127.0.0.1',
    port = 4222,
}

local client = nats.connect(params)
client:connect()
local function subscribe_callback(msg, reply)
    client:publish(reply, "Message Received")
end

local subscribe_id = client:subscribe('foo', subscribe_callback)
client:wait(10)
client:unsubscribe(subscribe_id)
