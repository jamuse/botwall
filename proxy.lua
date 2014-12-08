function CreateSeed()
    -- Change secret variable value below
    local secret = "ChangeMe"
    math.randomseed( os.time() )
    local rand = math.random()
    local key = rand .. secret
    return key
end

function GetParams()
    local args, err = ngx.req.get_uri_args()
    local pargs, err = ngx.req.get_post_args()
    for k,v in pairs(pargs) do args[k] = v end
    local parms
    if not args then
        ngx.log(ngx.ERR, "failed to get post args: ", err)
        return
    end
    for key, val in pairs(args) do
        if type(val) == "table" then
            ngx.log(ngx.ERR, key, ": ", table.concat(val, ", "))
            if parms == nil then 
                parms = key .. "=" .. val
            else
                parms = parms .. "&" .. key .. "=" .. val
            end
        else
            local HASHES = ngx.shared.hashes
            ngx.shared.hashes:flush_expired()
            local UnhashedKey = HASHES:get(key) or ""
            ngx.log(ngx.ERR, UnhashedKey, ": ", val)
            if parms == nil then
                parms = UnhashedKey .. "=" .. val
            else
                parms = parms .. "&" .. UnhashedKey .. "=" .. val
            end
        end
    end
    return parms
end

function ProxyGETRequest(Host, URI, Headers, Key)
    local http = require "resty.http"
    local httpc = http.new()
    httpc:set_timeout(5000)
    local ok, err = httpc:connect(Host, 80)
 
    local res, err = httpc:request{
        path = URI,
        headers = Headers,
    }
  
    ngx.status = res.status

    for k,v in pairs(res.headers) do
        --ngx.say(k, ": ", v)
        ngx.log(ngx.ERR, "Headers: ", k, " ", v)
        if k == "Location" then
            OrigV = v
            v = ngx.escape_uri(ngx.encode_base64(ngx.hmac_sha1(Key, v)))
            local HASHES = ngx.shared.hashes
            HASHES:set(v, OrigV, 86400)
        end
        ngx.header[k] = v
    end
    
    local body = res:read_body()
    ngx.say(body)

    local ok, err = httpc:set_keepalive()
    if not ok then
        ngx.say("failed to set keepalive: ", err)
        return
    end
end

function ProxyPOSTRequest(Host, URI, Params, Headers)
    Headers["Content-Length"] = #Params
    local http = require "resty.http"
    local httpc = http.new()
    httpc:set_timeout(5000)
    local ok, err = httpc:connect(Host, 80)

    local res, err = httpc:request{
        method = "POST",
        headers = Headers,
        path = URI,
        body = Params,
    }

    ngx.status = res.status

    for k,v in pairs(res.headers) do
        ngx.header[k] = v
        --ngx.say(k, ": ", v)
        ngx.log(ngx.ERR, "Headers: ", k, " ", v)
    end

    local body = res:read_body()
    ngx.say(body)

    local ok, err = httpc:set_keepalive()
    if not ok then
        ngx.say("failed to set keepalive: ", err)
        return
    end
end

function LookupURI(Hash)
    local URI = "/"
    local m = ""
    local HASHES = ngx.shared.hashes
    ngx.shared.hashes:flush_expired()
    
    local m, err = ngx.re.match(Hash, "/(.*)")

    if m then 
        local UnhashedURI = HASHES:get(m[1]) 
        if UnhashedURI then
            ngx.log(ngx.ERR, "UnhashedURI: ", UnhashedURI)
            local iterator1, err1 = ngx.re.gmatch(UnhashedURI, "^http", "i")
            local iterator2, err2 = ngx.re.gmatch(UnhashedURI, "^/")
            if not iterator1 then
                ngx.log(ngx.ERR, "REerror: ", err1)
                return
            end
            if not iterator2 then
                ngx.log(ngx.ERR, "REerror: ", err2)
                return
            end
 
            local n, er = iterator1()
            local o, er2 = iterator2()
            if er then
                ngx.log(ngx.ERR, "RE1error: ", er)
                return
            end
            if er2 then
                ngx.log(ngx.ERR, "RE1error: ", er)
                return
            end
            if n then
                if n[0] == "http" then URI = UnhashedURI end
            elseif o then
                if o[0] == "/" then URI = UnhashedURI end
            else
                URI = "/" .. UnhashedURI 
            end
        end
        ngx.log(ngx.ERR, "Hashed URI: ", Hash, " ", URI, " M1: ", m[1])
    
        ngx.shared.hashes:delete(m[1])
        ngx.shared.hashes:delete(Hash)
        return URI
    end
end


function main()
    -- Change the Host value to point to your backend server
    local Host = "ChangeMe"
    local Hash = ngx.var.request_uri
    local Key = CreateSeed()
    local Headers = ngx.req.get_headers(raw,true)

    -- Update host header and disable backend compression
    Headers["Host"] = Host
    Headers["Accept-Encoding"] = nil

    local Params = GetParams()
    ngx.log(ngx.ERR, "Params: ", Params)
    local URI = LookupURI(Hash)
    local Method = ngx.req.get_method()
    if Method == "GET" then
        ngx.log(ngx.ERR, "Method: ", Method)
        ProxyGETRequest(Host, URI, Headers, Key)
    elseif Method == "POST" then
        ngx.log(ngx.ERR, "Method: ", Method)
        ProxyPOSTRequest(Host, URI, Params, Headers)
    end
end

main()
