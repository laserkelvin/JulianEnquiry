
@def title = "What does a blog post look like?"
@def tags = ["test", "general"]
@def isblog = true
@def toc-image = "/assets/image_filler.png"
@def abstract = "If you wish to make apple pie, you must first create the Universe."

This is basically a lorem ipsum; I want to be able to see formatting, and test publishing
workflows.

Let's start with this hypothesis:

```julia:./code/ex1.jl
using Random

Random.seed!(13616)

a = rand(10)
b = rand(10)

a .* b
```
\show{./code/ex1}

# Structuring with CSS
