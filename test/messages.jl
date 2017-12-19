module MessagesTest

using Base.Test
if VERSION > v"0.7.0-DEV.2338"
using Unicode
end

using HTTP.Messages
import HTTP.Messages.appendheader
import HTTP.URI
import HTTP.RequestStack.request

using HTTP.StatusError

using JSON

@testset "HTTP.Messages" begin

    req = Request("GET", "/foo", ["Foo" => "Bar"])
    res = Response(200, ["Content-Length" => "5"]; body=Body("Hello"), parent=req)

    @test req.method == "GET"
    @test method(res) == "GET"

    #display(req); println()
    #display(res); println()

    @test String(req) == "GET /foo HTTP/1.1\r\nFoo: Bar\r\n\r\n"
    @test String(res) == "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello"

    @test header(req, "Foo") == "Bar"
    @test header(res, "Content-Length") == "5"
    setheader(req, "X" => "Y")
    @test header(req, "X") == "Y"

    appendheader(req, "" => "Z")
    @test header(req, "X") == "YZ"

    appendheader(req, "X" => "more")
    @test header(req, "X") == "YZ, more"

    appendheader(req, "Set-Cookie" => "A")
    appendheader(req, "Set-Cookie" => "B")
    @test filter(x->first(x) == "Set-Cookie", req.headers) == 
        ["Set-Cookie" => "A", "Set-Cookie" => "B"]

    @test Messages.httpversion(req) == "HTTP/1.1"
    @test Messages.httpversion(res) == "HTTP/1.1"

    raw = String(req)
    #@show raw
    req = Request()
    read!(IOBuffer(raw), req) 
    #display(req); println()
    @test String(req) == raw

    req = Request()
    read!(IOBuffer(raw * "xxx"), req) 
    @test String(req) == raw

    raw = String(res)
    #@show raw
    res = Response()
    read!(IOBuffer(raw), res) 
    #display(res); println()
    @test String(res) == raw

    res = Response()
    read!(IOBuffer(raw * "xxx"), res) 
    @test String(res) == raw

    for sch in ["http", "https"]
        for m in ["GET", "HEAD", "OPTIONS"]
            @test request(m, "$sch://httpbin.org/ip").status == 200
        end
        try 
            request("POST", "$sch://httpbin.org/ip")
            @test false
        catch e
            @test isa(e, StatusError)
            @test e.status == 405
        end
    end

#=
    @sync begin
        io = BufferStream()
        @async begin
            for i = 1:100
                sleep(0.1)
                write(io, "Hello!")
            end
            close(io)
        end
        yield() 
        r = request("POST", "http://httpbin.org/post", [], io)
        @test r.status == 200
    end
=#

    for sch in ["http", "https"]
        for m in ["POST", "PUT", "DELETE", "PATCH"]

            uri = "$sch://httpbin.org/$(lowercase(m))"
            r = request(m, uri)
            @test r.status == 200
            body = take!(r.body)

            io = BufferStream()
            r = request(m, uri, response_stream=io)
            @test r.status == 200
            @test read(io) == body
        end
    end
    for sch in ["http", "https"]
        for m in ["POST", "PUT", "DELETE", "PATCH"]

            uri = "$sch://httpbin.org/$(lowercase(m))"
            io = BufferStream()
            r = request(m, uri, response_stream=io)
            @test r.status == 200
        end
    end


    mktempdir() do d
        cd(d) do

            n = 50
            io = open("result_file", "w")
            r = request("GET", "http://httpbin.org/stream/$n",
                        response_stream=io)
            @test stat("result_file").size == 0
            while stat("result_file").size <= 1000
                sleep(0.1)
            end
            @test stat("result_file").size > 1000
            i = 0
            for l in readlines("result_file")
                x = JSON.parse(l)
                @test i == x["id"]
                i += 1
            end
            @test i == n
        end
    end
end

end # module MessagesTest
