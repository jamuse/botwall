local gumbo = require "gumbo"

function CreateSeed()
    -- Change secret parameter value below
    local secret = "ChangeMe"
    math.randomseed( os.time() )
    local rand = math.random()
    local key = rand .. secret
    return key
end

function OTP(Key, Element,Attribute)
    for i, element in ipairs(Element) do
        local Attr = element:getAttribute(Attribute)
        if Attr and Attr ~= "" then
            ngx.log(ngx.ERR, "Attr: ", Attr)
            local HMAC = ""
            if ngx.re.match(Attr, "#") then do return end end
            if ngx.re.match(Attr, "window.open") then
                local m, err = ngx.re.match(Attr, "(window.open\\([\'\"])([^\"\']+)(.*$)")
                if m then
                    local AttrOTP = ngx.escape_uri(ngx.encode_base64(ngx.hmac_sha1(Key, m[2])))
                    HMAC = m[1] .. AttrOTP .. m[3]
                    local HASHES = ngx.shared.hashes
                    HASHES:set(AttrOTP, m[2], 86400)
                end
            else
                HMAC = ngx.escape_uri(ngx.encode_base64(ngx.hmac_sha1(Key, Attr)))
                ngx.log(ngx.ERR, "HASHES: ", HMAC, " Attr: ", Attr)
                local HASHES = ngx.shared.hashes
                HASHES:set(HMAC, Attr, 86400)
            end
            element:setAttribute(Attribute, HMAC)
        end
    end
end

function main()
    local h = ngx.resp.get_headers()
    ngx.log(ngx.ERR, "Response: ", ngx.status)
    ngx.log(ngx.ERR, "Content-Type: ", ngx.resp.get_headers()["Content-Type"])
    if ngx.re.match(ngx.resp.get_headers()["Content-Type"], "text/html") then

        --ngx.log(ngx.ERR, "Demo: ", ngx.arg[1])
        local Key = CreateSeed()
        ngx.log(ngx.ERR, "Key: ", Key)

        local document = assert(gumbo.parse(ngx.arg[1]))
        local Links = document:getElementsByTagName("link")
        local Hyperlinks = document:getElementsByTagName("a")
        local Images = document:getElementsByTagName("img")
        local Forms = document:getElementsByTagName("form")
        local Inputs = document:getElementsByTagName("input")

        OTP(Key, Links, "href")
        OTP(Key, Hyperlinks, "onclick")
        OTP(Key, Hyperlinks, "href")
        OTP(Key, Images, "src")
        --if Forms ~= "" then OTP(Key, Forms, "action") end
        OTP(Key, Forms, "action")
        OTP(Key, Inputs, "id")
        OTP(Key, Inputs, "name")

        --ngx.say(document.documentElement.outerHTML, "\n")
        ngx.log(ngx.ERR, document.documentElement.outerHTML, "\n")
        ngx.arg[1] = document.documentElement.outerHTML
    end
end

main()
