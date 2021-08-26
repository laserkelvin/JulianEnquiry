
using Dates

function hfun_bar(vname)
  val = Meta.parse(vname[1])
  return round(sqrt(val), digits=2)
end

function hfun_m1fill(vname)
  var = vname[1]
  return pagevar("index", var)
end

function lx_baz(com, _)
  # keep this first line
  brace_content = Franklin.content(com.braces[1]) # input string
  # do whatever you want here
  return uppercase(brace_content)
end

"""
    {{blogposts}}
Plug in the list of blog posts contained in the `/blog/` folder.

Taken from the JuliaLang site utils.jl
"""
function hfun_blogposts()
    curyear = year(Dates.today())
    io = IOBuffer()
    for year in curyear:-1:2021
        ys = "$year"
        year < curyear && write(io, "\n**$year**\n")
        for month in 12:-1:1
            ms = "0"^(month < 10) * "$month"
            base = joinpath("blog", ys, ms)
            isdir(base) || continue
            posts = filter!(p -> endswith(p, ".md"), readdir(base))
            days  = zeros(Int, length(posts))
            lines = Vector{String}(undef, length(posts))
            for (i, post) in enumerate(posts)
                ps  = splitext(post)[1]
                url = "/blog/$ys/$ms/$ps/"
                surl = strip(url, '/')
                title = pagevar(surl, :title)
				title === nothing && (title = "Untitled")
                pubdate = pagevar(surl, :published)
                if isnothing(pubdate)
                    date    = "$ys-$ms-01"
                    days[i] = 1
                else
                    date    = Date(pubdate, dateformat"d U Y")
                    days[i] = day(date)
                end
                lines[i] = "\n$date [$title]($url) \n"
            end
            # sort by day
            foreach(line -> write(io, line), lines[sortperm(days, rev=true)])
        end
    end
    # markdown conversion adds `<p>` beginning and end but
    # we want to  avoid this to avoid an empty separator
    r = Franklin.fd2html(String(take!(io)), internal=true)
    return r
end

"""
Taken from the MIT computational thinking site deployment
"""
function hfun_plutonotebookpage(params)
    path = params[1]
    path_to_html = if endswith(path, ".jl")
        path[1:end-3] * ".html"
    else
        path * ".html"
    end

    # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Feature-Policy#directives

    return """
    <style>
    .content {
        max-width: 100%;
        margin-right: 0px;
        padding: 0px;
        overflow-y: hidden;
        height: 100vh;
    }
    .franklin-content {
        padding: 0px;
    }
    .page-foot {
        display: none;
    }
    .plutopage {
        height: 100vh;
    }
    .smallscreenlink {
        display: none;
    }
    @media (max-width: 768px) {
        .franklin-content {
            padding: 0px;
        }
    }
    </style>
    
    <iframe width="100%" height="100%"
    src="$(path_to_html)"
    class="plutopage"
    frameborder="0"
    allow="accelerometer; ambient-light-sensor; autoplay; battery; camera; display-capture; document-domain; encrypted-media; execution-while-not-rendered; execution-while-out-of-viewport; fullscreen; geolocation; gyroscope; layout-animations; legacy-image-formats; magnetometer; microphone; midi; navigation-override; oversized-images; payment; picture-in-picture; publickey-credentials-get; sync-xhr; usb; wake-lock; screen-wake-lock; vr; web-share; xr-spatial-tracking"
    allowfullscreen></iframe>
    <a class="smallscreenlink" href="$(path_to_html)"></a>
    """
end